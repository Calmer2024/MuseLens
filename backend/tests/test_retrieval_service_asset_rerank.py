from app.schemas.retrieval import LensAssetSchema, LensKnowledge
from app.services.retrieval_service import RetrievalService


def test_available_mask_prefers_mask_consumers_over_mask_providers():
    consumer = LensKnowledge(
        lens_id="lens_flux_inpaint",
        score=1.0,
        inputs=[
            LensAssetSchema(name="base_image", type="image"),
            LensAssetSchema(name="mask", type="mask"),
        ],
        outputs=[LensAssetSchema(name="result_image", type="image")],
    )
    provider = LensKnowledge(
        lens_id="lens_sam2_matting",
        score=1.0,
        inputs=[LensAssetSchema(name="base_image", type="image")],
        outputs=[LensAssetSchema(name="mask_result", type="mask")],
    )

    ranked = RetrievalService._rerank_by_available_user_assets(
        [provider, consumer],
        available_user_assets={"mask": "mask_xxx.png"},
    )

    assert [item.lens_id for item in ranked] == [
        "lens_flux_inpaint",
        "lens_sam2_matting",
    ]


def test_dependency_expansion_skips_provider_when_user_already_has_mask():
    candidate = LensKnowledge(
        lens_id="lens_flux_inpaint",
        score=1.0,
        inputs=[
            LensAssetSchema(name="base_image", type="image"),
            LensAssetSchema(name="mask", type="mask"),
        ],
        outputs=[LensAssetSchema(name="result_image", type="image")],
    )

    class _Rec:
        def __init__(self, lens_id, outputs):
            self.lens_id = lens_id
            self.outputs = outputs

    records = [
        _Rec("lens_sam2_matting", [{"name": "mask_result", "type": "mask"}]),
    ]

    deps = RetrievalService._find_dependency_lens_ids(
        RetrievalService.__new__(RetrievalService),
        candidate,
        records,
        exclude_ids={candidate.lens_id},
        limit=3,
        available_user_assets={"mask": "mask_xxx.png"},
    )

    assert deps == []


def test_wanted_lens_ids_for_scene_relight_and_delivery_task():
    wanted = RetrievalService._wanted_lens_ids_for_task(
        "保持图中女人的姿势，让她躺在海边的沙滩上，调节光影让黄昏的光从图片的左上方柔和的照下，最终的图片画质要好，足够清晰"
    )

    assert wanted == [
        "lens_flux_reference",
        "lens_pose_extract",
        "lens_relighting",
        "lens_depth_extract",
        "lens_upscale_4x",
    ]
