"""
MuseLens 动态 DAG 编译器 (MuseDNACompiler) v2.0

负责解析由 LLM 生成的 DAGBlueprint。
具备真正的拓扑寻址能力：
  能够将类似 `$step_1.core_mask` 的依赖变量解析为上游的真实历史文件。
采用纯异步非阻塞执行：
  调用 AsyncComfyRunner，并在每一步执行完毕后对外发射 WebSocket 进度事件。
"""

import json
import asyncio
import os
import copy
import logging
import shutil
from typing import Callable, Awaitable, Dict, Any

from app.schemas.lens import DAGBlueprint, LensTemplate
from app.lenses.registry import get_lens
from app.services.comfy_service import AsyncComfyRunner


# ComfyUI 的 output 目录 (根据实际安装路径修改)
COMFYUI_OUTPUT_DIR = os.environ.get(
    "COMFYUI_OUTPUT_DIR",
    r"E:\ComfyUI\ComfyUI_windows_portable\ComfyUI\output",
)
COMFYUI_INPUT_DIR = os.environ.get(
    "COMFYUI_INPUT_DIR",
    r"E:\ComfyUI\ComfyUI_windows_portable\ComfyUI\input",
)

logger = logging.getLogger(__name__)

# 定义类型注解，这是一个回调函数，接受 (step_id, 当前已有的全部上下文资产)，返回空协程
ProgressCallback = Callable[[str, Dict[str, str]], Awaitable[None]]
StepStartedCallback = Callable[[str, str, int, int], Awaitable[None]]

class MuseDNACompiler:
    """
    负责将 DAGBlueprint 编译为底层的 ComfyUI 请求序列，
    并维护一个局部的"黑板 (Context)"记录每一步输出文件的真实路径。
    """
    def __init__(self, input_dir: str, output_dir: str):
        """
        初始化编译器
        :param input_dir: ComfyUI 的 input 目录路径（接收文件的位置）
        :param output_dir: ComfyUI 的 output 目录路径（生成文件的位置）
        """
        self.input_dir = input_dir
        self.output_dir = output_dir

    def _resolve_asset(
        self,
        link_value: str,
        context: Dict[str, str],
        asset_locations: Dict[str, Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        [资产解析 (Asset Resolution)]
        解析 input_links 中的引用，如果它是变量（如 '$step_1.core_mask'），
        则从 context 字典中取出原本的本地真实文件名。如果是硬编码路径则直接返回。
        """
        if link_value.startswith("$"):
             # 去掉 '$' 符号
             var_name = link_value[1:]
             logger.info(f"[Compiler] Resolving asset link: {link_value} -> reading context key '{var_name}'")
             if var_name not in context:
                  raise RuntimeError(f"变量引用 {link_value} 在当前上下文中未找到 (可用: {list(context.keys())})")
             actual_path = context[var_name]
             info = asset_locations.get(var_name, {"filename": actual_path, "subfolder": "", "type": "output"})
             logger.info(f"[Compiler] Resolved asset: {link_value} -> {info}")
             return info
         
        # 非变量时（例如纯静态文件的名称），直接当作真实文件名处理
        logger.info(f"[Compiler] Static asset provided: {link_value}")
        return {"filename": link_value, "subfolder": "", "type": "input"}

    def _ensure_asset_in_input_dir(self, asset_info: Dict[str, Any]) -> str:
        filename = str(asset_info.get("filename") or "")
        if not filename:
            raise RuntimeError(f"资产信息缺少 filename: {asset_info}")

        dst_input = os.path.join(self.input_dir, filename)
        if os.path.exists(dst_input):
            return filename

        subfolder = str(asset_info.get("subfolder") or "")
        src_folder = self.output_dir
        if subfolder:
            src_folder = os.path.join(src_folder, subfolder)
        src_output = os.path.join(src_folder, filename)

        if os.path.exists(src_output):
            shutil.copy2(src_output, dst_input)
            logger.info(
                f"[Compiler/Mover] Copied generated output {src_output} to downstream input {dst_input}."
            )
            return filename

        if asset_info.get("type") == "input":
            return filename

        raise RuntimeError(
            f"Downstream asset not found in ComfyUI input/output dirs: filename={filename}, "
            f"subfolder={subfolder!r}, expected_input={dst_input}, expected_output={src_output}"
        )

    def _inject_dependencies(self, template: LensTemplate, 
                             resolved_assets: Dict[str, str], 
                             params: Dict[str, Any]) -> dict:
        """
        [动态注入 (Dynamic Assignment)]
        基于 LensTemplate（它的 inputs 和 params 的映射配置），生成一份供丢给 ComfyRunner 执行的 JSON dict。
        """
        # 复制一份纯净模板
        workflow = copy.deepcopy(template.raw_workflow)
        
        # 1. 注入 Assets (文件路径类)
        for asset in template.inputs:
             if asset.name not in resolved_assets:
                 raise ValueError(f"缺少必须的资产输入: {asset.name}")
             val = resolved_assets[asset.name]
             workflow[asset.mapping.node_id]["inputs"][asset.mapping.field_name] = val
             
        # 2. 注入 Params (LLM 直接给出的标量)
        for param in template.params:
             if param.name not in params:
                 # 如果 LLM 没给参数，直接看 ComfyUI 本身的默认值即可，不强制报错（或采取备选）
                 logger.warning(f"透镜 {template.lens_id} 应该接收的控制参数 {param.name} 为空，跳过注入默认采用模板原值。")
                 continue
             val = params[param.name]
             workflow[param.mapping.node_id]["inputs"][param.mapping.field_name] = val
             
        return workflow

    async def execute_blueprint(self, blueprint: DAGBlueprint,
                                progress_callback: ProgressCallback = None,
                                step_started_callback: StepStartedCallback = None) -> Dict[str, str]:
        """
        异步非阻塞执行完整的蓝图引擎。
        """
        # 初始化黑板上下文
        context = {**blueprint.initial_inputs}
        asset_locations: Dict[str, Dict[str, Any]] = {
            key: {"filename": value, "subfolder": "", "type": "input"}
            for key, value in blueprint.initial_inputs.items()
            if isinstance(value, str)
        }
        logger.info(f"[Compiler] Blueprint Started. Initial context: {context}")
        
        runner = AsyncComfyRunner()
        try:
             # 遍历图节点 (预设为已经过拓扑排序)
             total_steps = len(blueprint.steps)
             for idx, step in enumerate(blueprint.steps, start=1):
                  logger.info(f"[Compiler] Executing step: {step.step_id} (Lens: {step.lens_id})")
                  if step_started_callback:
                       await step_started_callback(
                           step.step_id,
                           step.lens_id,
                           idx,
                           total_steps,
                       )
                  
                  # 1. 读取透镜字典
                  lens_template = get_lens(step.lens_id)
                  
                  # 2. 资产解析：将 $step_X.YY 转化成上下文里的真实物理路径名
                  resolved_assets = {}
                  for asset_name, link_value in step.input_links.items():
                       # 对于这个 step 来说，asset_name (如 'base_image') 需要被装载真实路径 
                       actual_asset = self._resolve_asset(link_value, context, asset_locations)
                       actual_filename = self._ensure_asset_in_input_dir(actual_asset)
                       resolved_assets[asset_name] = actual_filename
                  
                  # 3. 生成运行时 workflow json
                  injected_workflow = self._inject_dependencies(
                      template=lens_template,
                      resolved_assets=resolved_assets,
                      params=step.params
                  )
                  
                  # 4. 提交给 ComfyUI 异步跑
                  try:
                      prompt_id = await runner.queue_prompt(injected_workflow)
                  except Exception as exc:
                      raise RuntimeError(
                          f"Step {step.step_id} ({step.lens_id}) failed to queue in ComfyUI: {exc}"
                      ) from exc
                  logger.info(f"[{step.step_id}] sent to queue, id={prompt_id}. Waiting for completion...")
                  
                  # 5. 阻塞当步，直至本步渲染结束
                  await runner.wait_for_completion(prompt_id)
                  
                  # 6. 从输出收集结果，回填上下文黑板
                  step_outputs = {}
                  for output_asset in lens_template.outputs:
                        image_info = await runner.get_output_image_info(prompt_id, output_asset.mapping.node_id)
                        file_name = str(image_info["filename"])
                        var_key = f"{step.step_id}.{output_asset.name}"
                        context[var_key] = file_name
                        asset_locations[var_key] = image_info
                        step_outputs[output_asset.name] = file_name
                        logger.info(f"[Compiler] Captured output {output_asset.name} as {file_name} -> storing to context key '{var_key}'")
                  
                  # 7. 触发回调，发射 WebSocket 进度给前台
                  if progress_callback:
                       await progress_callback(step.step_id, step_outputs)
                       
        finally:
             await runner.close()
             
        return context
