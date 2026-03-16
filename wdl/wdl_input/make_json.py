#!/usr/bin/env python
from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from pydantic import (
        BaseModel,
        ConfigDict,
        field_validator,
        model_validator,
    )

EXAMPLE_INPUT_JSON = {
    "QCpipeline.is_hc": "Boolean",
    "QCpipeline.is_qc": "Boolean",
    "QCpipeline.batch_name": "String",
    "QCpipeline.hc_sample_info": "File? (optional)",
    "QCpipeline.is_align": "Boolean",
    "QCpipeline.align_sample_info": "File? (optional)",
    "QCpipeline.qc_sample_info": "File? (optional)",
    "QCpipeline.gpu_ids": "Array[Array[Int]]",
    "QCpipeline.cfg": {
        "snp_stat": "File",
        "bgzip": "File",
        "ref": "File",
        "samtools": "File",
        "fastp_stat": "File",
        "bcftools": "File",
        "fastp": "File",
        "Rscript": "File",
        "popSNP_SNPStat": "File",
        "chr_list": "File",
        "parallel": "File",
        "fai": "File",
        "py": "File"
    },
    "QCpipeline.output_dir": "String"
}

def _strip_non_empty(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("不能为空字符")
    return value

def _path_to_str(value: Path | None) -> str | None:
    return None if value is None else str(value)

class StrictBaseModel(BaseModel):
    model_config = ConfigDict(extra='forbid')

class ConfigModel(StrictBaseModel):
    snp_stat: Path
    bgzip: Path
    ref: Path
    samtools: Path
    fastp_stat: Path
    bcftools: Path
    fastp: Path
    Rscript: Path
    popSNP_SNPStat: Path
    chr_list: Path
    parallel: Path
    fai: Path
    py: Path

class SampleInfoOverride(StrictBaseModel):
    sample_info: Path | None = None

class InputSourceModel(StrictBaseModel):
    batch_name: str
    output_dir: str
    is_qc: bool
    is_align: bool
    is_hc: bool
    qc_sample_info: Path | None = None
    align_sample_info: Path | None = None
    hc_sample_info: Path | None = None
    gpu_ids: list[list[int]] = [[0, 1], [2, 3], [4, 5]]
    cfg: ConfigModel

    @field_validator("batch_name", "output_dir")
    @classmethod
    def validate_non_empty_string(cls, value: str):
        return _strip_non_empty(value)
    
    @field_validator("gpu_ids")
    @classmethod
    def validate_gpu_ids(cls, value: list[list[int]]):
        if not value:
            raise ValueError("gpu_ids 不能为空")
        for group in value:
            if not group:
                raise ValueError("gpu_ids的元素也不能为空")
            for gpu_id in group:
                if gpu_id < 0:
                    raise ValueError("gpu_id中的每个值都不能小于0")
        return value
    
    @model_validator(mode="after")
    def validate_mode_and_required_inputs(self) -> InputSourceModel:
        enabled_count = sum([self.is_qc, self.is_align, self.is_hc])
        if enabled_count != 1:
            raise ValueError("is_qc、is_align、is_hc 有且仅有一个为真")
        
        if self.is_qc and self.qc_sample_info is None:
            raise ValueError("当 is_qc=true 时, qc_sample_info 为必填")
        if self.is_align and self.align_sample_info is None:
            raise ValueError("当 is_align=true 时, align_sample_info 为必填")
        if self.is_hc and self.hc_sample_info is None:
            raise ValueError("当 is_hc=true 时, hc_sample_info 为必填")
        return self
    
    def to_wdl_input(self) -> dict[str, Any]:
        return {
            "QCpipeline.is_hc": self.is_hc,
            "QCpipeline.is_qc": self.is_qc,
            "QCpipeline.batch_name": self.batch_name,
            "QCpipeline.hc_sample_info": _path_to_str(self.hc_sample_info),
            "QCpipeline.is_align": self.is_align,
            "QCpipeline.align_sample_info": _path_to_str(self.align_sample_info),
            "QCpipeline.qc_sample_info": _path_to_str(self.qc_sample_info),
            "QCpipeline.gpu_ids": self.gpu_ids,
            "QCpipeline.cfg": {
                "snp_stat": _path_to_str(self.cfg.snp_stat),
                "bgzip": _path_to_str(self.cfg.bgzip),
                "ref": _path_to_str(self.cfg.ref),
                "samtools": _path_to_str(self.cfg.samtools),
                "fastp_stat": _path_to_str(self.cfg.fastp_stat),
                "bcftools": _path_to_str(self.cfg.bcftools),
                "fastp": _path_to_str(self.cfg.fastp),
                "Rscript": _path_to_str(self.cfg.Rscript),
                "popSNP_SNPStat": _path_to_str(self.cfg.popSNP_SNPStat),
                "chr_list": _path_to_str(self.cfg.chr_list),
                "parallel": _path_to_str(self.cfg.parallel),
                "fai": _path_to_str(self.cfg.fai),
                "py": _path_to_str(self.cfg.py),
            },
            "QCpipeline.output_dir": self.output_dir,
        }

def args_init() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="使用 pydantic 校验配置，并生成符合 QCpipeline 模板的 input.json"
    )
    parser.add_argument(
        "--outdir",
        dest="outdir",
        type=str,
        default=None,
        help="分析输出的项目路径地址"
    )
    parser.add_argument(
        "--batch",
        dest="batch",
        type=str,
        default="test",
        help="分析的批次名"
    )
    parser.add_argument(
        "--config",
        dest="config",
        type=str,
        default="config.json",
        help="配置流程输入额外的软件及步骤必须文件"
    )
    parser.add_argument(
        "--is-qc",
        dest="is_qc",
        help="是否是从qc开始执行流程",
        action="store_true"
    )
    parser.add_argument(
        "--is-align",
        dest="is_align",
        help="是否是从align开始执行流程",
        action="store_true"
    )
    parser.add_argument(
        "--is-hc",
        dest="is_hc",
        help="是否是从hc开始执行流程",
        action="store_true"
    )
    parser.add_argument(
        "--qc-info",
        dest="qc_info",
        type=Path,
        default=None,
        help="提供qc步骤需要的json文件, key为样本名, value为r1和r2数组"
    )
    parser.add_argument(
        "--align-info",
        dest="align_info",
        type=Path,
        default=None,
        help="提供align步骤需要的json文件, key为样本名, value为clean后的r1和r2数组"
    )
    parser.add_argument(
        "--hc-info",
        dest="hc_info",
        type=Path,
        default=None,
        help="提供hc步骤需要的json文件, key为样本名, value为对应的bam和bai文件数组"
    )
    parser.add_argument(
        "--output",
        dest="out",
        type=Path,
        default=Path("input.json"),
        help="生成的 WDL input JSON 输出路径，默认: input.json"
    )
    parser.add_argument(
        "--print-example",
        dest="example",
        action="store_true",
        help="打印一个可直接修改的源配置 JSON 示例"
    )
    return parser.parse_args()

