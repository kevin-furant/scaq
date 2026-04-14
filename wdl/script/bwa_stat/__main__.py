#!/usr/bin/env python
import argparse
from pathlib import Path
from .bwa_stat_plot import BwaStatsPlot
def main():
    parser = argparse.ArgumentParser(  
        description='bwa stat and plot!')  
    parser.add_argument(  
        '--input', '-i', metavar='str', type=str, required=True,
        help='input bam path.')  
    parser.add_argument(  
        '--output', '-o', metavar='str', type=str, required=True,
        help='result output path.')
    parser.add_argument(  
        '--genome_length', '-g', metavar='int', type=int, required=True,
        help='genome length.')  
    args = parser.parse_args()
    bwa_stat_plot = BwaStatsPlot(Path(args.input), args.genome_length, Path(args.output))
    bwa_stat_plot.get_stats_result()
    bwa_stat_plot.plot_stats()

if __name__ == '__main__':
    main()