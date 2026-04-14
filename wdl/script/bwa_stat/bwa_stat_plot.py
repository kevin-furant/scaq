#!/usr/bin/env python
from __future__ import annotations
from pathlib import Path
import os
from pydantic import BaseModel, ConfigDict, model_validator
from typing import List, Any, Optional
import pandas as pd
from .stat_plot import plot

"""
merge samples bwa stats and put out a PDF plot File
"""

class BwaStats(BaseModel):
    """
    bwa stats output
    """
    model_config = ConfigDict(arbitrary_types_allowed=True)
    bam_files: List[Path]
    bai_files: List[Path]
    bwa_stat_files: List[Path]
    chrs_txt_files: List[Path]

    @model_validator(mode="after")
    def check_file_num(self) -> Optional[BwaStats]:
        if len(self.bam_files) != len(self.bai_files) or len(self.bam_files) != len(self.bwa_stat_files) or len(self.bam_files) != len(self.chrs_txt_files):
            raise ValueError("bwa stats plot file number error")
        return self
    
class BwaStatsPlot(object):
    """
    bwa stats plot
    """
    def __init__(self, bam_path: Path, genome_length: int, result_dir: Path):
        self.bam_path = bam_path
        self.genome_length = genome_length
        self.result_dir = result_dir
        self.bams = []
        self.bais = []
        self.bwa_stats = []
        self.chr_txts = []
        self.find_files()

    def find_files(self) -> BwaStats:
        for root, dirs, files in os.walk(self.bam_path, topdown=False):
            for file in files:
                if file.endswith(".bam"):
                    self.bams.append(Path(root) / file)
                elif file.endswith(".bai"):
                    self.bais.append(Path(root) / file)
                elif file.endswith(".stat"):
                    self.bwa_stats.append(Path(root) / file)
                elif file.endswith("chrs.txt"):
                    self.chr_txts.append(Path(root) / file)
                else:
                    pass
        return BwaStats(
            bam_files=self.bams,
            bai_files=self.bais,
            bwa_stat_files=self.bwa_stats,
            chrs_txt_files=self.chr_txts
        )
    
    def get_stats(self):
        "extract info from bwa stats file"
        coverage_target_list = [1, 2, 5, 10, 15, 20, 30, 40, 50, 100]
        coverage_target_columns = ['Coverage_%sX' % dep for dep in coverage_target_list]
        df = pd.DataFrame(columns=[
            "Sample", "Clean_reads", "Clean_bases(bp)", "tmapped_reads", 
            "mapped_bases(bp)", "mismatch_bases(bp)", "mapping_rate",
            "mismatch_rate", "Average_depth"
        ] + coverage_target_columns)
        column_names = df.columns.to_list()
        for sample_bwa_stat_file in self.bwa_stats:
            sample_name = sample_bwa_stat_file.name.split(".")[0]
            coverage_tmp_dict = {}
            with open(sample_bwa_stat_file, "r") as inf:
                collect_dict = {
                        'sequences': None,
                        'reads paired': None,
                        'reads mapped': None,
                        'reads unmapped': None,
                        'reads duplicated': None,
                        'total length': None,
                        'bases mapped': None,
                        'mismatches': None,
                        'average length': None,
                        'pairs on different chromosomes': None
                }
                for each in inf:
                    each = each.strip()
                    line_list = each.split('\t')
                    if each.startswith('SN'):
                        item = line_list[1].replace(':', '').strip()
                        if collect_dict.get(item) is None:
                            collect_dict[item] = int(line_list[2])
                    elif each.startswith('COV'):
                        cover_dis = line_list[1]
                        if cover_dis == '[100<]':
                            continue
                        cov_dep = int(line_list[2])
                        cov_base = int(line_list[3])
                        coverage_tmp_dict[cov_dep] = cov_base
            Clean_reads = collect_dict['sequences']
            Clean_bases = collect_dict['total length']
            mapped_reads = collect_dict['reads mapped']
            mapped_bases = collect_dict['bases mapped']
            mismatch_bases = collect_dict['mismatches']
            mapping_rate = '%.2f' % round(mapped_bases / Clean_bases * 100, 2)
            mismatch_rate = '%.2f' % round(mismatch_bases / Clean_bases * 100, 2)
            average_depth = '%.2f' % round(Clean_bases / self.genome_length, 2)               

            coverage_list = []
            for coverage_target in coverage_target_list:
                cov_base = 0
                for cov_dep in coverage_tmp_dict.keys():
                    if cov_dep >= coverage_target:
                        cov_base += coverage_tmp_dict[cov_dep]
                    else:
                        cov_base += 0
                cov_rate = '%.2f%s' % (round(cov_base/self.genome_length*100, 2), '%')
                coverage_list.append(cov_rate)
            _df = pd.DataFrame(dict(zip(column_names, 
                                        [sample_name, Clean_reads, Clean_bases, 
                                        mapped_reads, mapped_bases, mismatch_bases, 
                                        mapping_rate, mismatch_rate, average_depth] + coverage_list)))
            df = pd.concat([df, _df], ignore_index=True)
        self.df = df
        return df
    
    def get_stats_result(self):
        self.get_stats()
        self.df.to_csv(self.result_dir / "bwa_result.tsv", sep='\t', index=False)
    
    def plot_stats(self):
        "plot bwa stats"
        plot(self.df, self.result_dir)
            