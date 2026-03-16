#!/usr/bin/env python
from . import EXAMPLE_INPUT_JSON, InputSourceModel, args_init, ConfigModel
from pydantic import ValidationError
from pathlib import Path
from typing import Dict
import json, sys

def get_config_dict(config_json: Path | str) -> Dict[str, Path] | None:
    with open(config_json, "r", encoding="utf-8") as inf:
        _dict = json.load(inf)
    config_dict = {}
    for key, value in _dict.items():
        if value is None:
            config_dict[key] = None
        else:
            try:
                config_dict[key] = Path(value)
            except TypeError as err:
                raise ValueError(f"字段 {key} 的值 {value} 无法转换为 Path 类型")
    return config_dict
        
if __name__ == "__main__":
    # config_json = Path(__file__).parent / "config.json"
    args = args_init()
    config_json = Path(args.config)
    if args.example:
        print(json.dumps(EXAMPLE_INPUT_JSON, ensure_ascii=False, indent=2))
        sys.exit(0)
    config_dict = get_config_dict(config_json)
    cfg_obj = ConfigModel(**config_dict)
    input_source_model_obj = InputSourceModel(
        batch_name = args.batch,
        output_dir = args.outdir,
        is_qc = args.is_qc,
        is_align = args.is_align,
        is_hc = args.is_hc,
        qc_sample_info = args.qc_info,
        align_sample_info = args.align_info,
        hc_sample_info = args.hc_info,
        cfg = cfg_obj
    )
    input_json_dict = input_source_model_obj.to_wdl_input()
    with open(args.out, "w", encoding="utf-8") as outf:
        json.dump(input_json_dict, outf, indent=4, ensure_ascii=False, sort_keys=False)