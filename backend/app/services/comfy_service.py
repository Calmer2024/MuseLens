import json
import urllib.request
import urllib.parse
import requests
import websocket # pip install websocket-client
import uuid
import os

# ComfyUI 地址 (根据你实际情况修改)
COMFY_URL = "127.0.0.1:8188"
SERVER_ADDRESS = f"http://{COMFY_URL}"
WS_ADDRESS = f"ws://{COMFY_URL}/ws?clientId="

class ComfyService:
    def __init__(self):
        self.client_id = str(uuid.uuid4())
        self.ws = websocket.WebSocket()
        self.ws.connect(WS_ADDRESS + self.client_id)

    def upload_image(self, file_path, file_name, image_type="input"):
        """上传图片到 ComfyUI 的 input 目录"""
        with open(file_path, 'rb') as f:
            files = {"image": (file_name, f)}
            data = {"type": image_type, "overwrite": "true"}
            response = requests.post(f"{SERVER_ADDRESS}/upload/image", files=files, data=data)
            return response.json()

    def queue_prompt(self, workflow_json):
        """发送工作流任务"""
        p = {"prompt": workflow_json, "client_id": self.client_id}
        data = json.dumps(p).encode('utf-8')
        req = urllib.request.Request(f"{SERVER_ADDRESS}/prompt", data=data)
        return json.loads(urllib.request.urlopen(req).read())

    def get_history(self, prompt_id):
        """获取生成历史"""
        with urllib.request.urlopen(f"{SERVER_ADDRESS}/history/{prompt_id}") as response:
            return json.loads(response.read())

    def get_image(self, filename, subfolder, folder_type):
        """下载生成的图片"""
        data = {"filename": filename, "subfolder": subfolder, "type": folder_type}
        url_values = urllib.parse.urlencode(data)
        with urllib.request.urlopen(f"{SERVER_ADDRESS}/view?{url_values}") as response:
            return response.read()

    # 🔥 关键修改：去掉了 mask_path 参数
    def generate_image(self, input_path, prompt_text):
        try:
            # 1. 上传图片 (只传原图，不再传 mask)
            self.upload_image(input_path, "input_image.png")
            
            # 2. 读取工作流 JSON (确保这里的路径是对的)
            workflow_path = os.path.join(os.path.dirname(__file__), "../workflows/img2img_api.json")
            
            if not os.path.exists(workflow_path):
                print(f"Error: Workflow file not found at {workflow_path}")
                return None

            with open(workflow_path, 'r', encoding='utf-8') as f:
                workflow = json.load(f)

            # 3. 修改节点参数 (根据 img2img_api.json 的 ID)
            # 正向提示词 (ID: 6)
            workflow["6"]["inputs"]["text"] = prompt_text 
            # 原图加载 (ID: 10)
            workflow["10"]["inputs"]["image"] = "input_image.png"
            
            # 注意：不再修改 ID 为 11 的蒙版节点，因为新工作流里没有它了

            # 4. 发送任务
            prompt_id = self.queue_prompt(workflow)['prompt_id']
            
            # 5. 监听 WebSocket 等待完成
            while True:
                out = self.ws.recv()
                if isinstance(out, str):
                    message = json.loads(out)
                    if message['type'] == 'executing':
                        data = message['data']
                        if data['node'] is None and data['prompt_id'] == prompt_id:
                            break # 执行完成

            # 6. 获取结果
            history = self.get_history(prompt_id)[prompt_id]
            for node_id in history['outputs']:
                node_output = history['outputs'][node_id]
                if 'images' in node_output:
                    image_info = node_output['images'][0]
                    # 下载图片数据
                    image_data = self.get_image(image_info['filename'], image_info['subfolder'], image_info['type'])
                    return image_data

        except Exception as e:
            print(f"Error generating image: {e}")
            return None