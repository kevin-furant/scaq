#!/home/liuzhexin/soft/micromamba/envs/snakemake/bin/python

import argparse
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path


def percen_2_float(x):
    return float(x.replace('%', ''))


def str_2_float(x):
    return float(x)


def style_axis(ax):
    """Apply a clean scientific-paper style to an axis"""
    ax.grid(
        axis='y',
        color='#d9d9d9',
        linestyle='--',
        linewidth=0.8
    )
    ax.set_axisbelow(True)

    for spine in ax.spines.values():
        spine.set_linewidth(0.8)
        spine.set_color('#666666')


def plot_all(df, stack_cov, out_dir):

    # ---- global matplotlib style ----
    plt.rcParams.update({
        "font.size": 11,
        "axes.labelsize": 11,
        "axes.titlesize": 12,
        "xtick.labelsize": 10,
        "ytick.labelsize": 10,
        "axes.linewidth": 0.8,
        "figure.facecolor": "white"
    })

    fig, axes = plt.subplots(
        1, 3,
        figsize=(8.5, 3),
        gridspec_kw={'width_ratios': [0.7, 0.7, 1.3]}
    )

    # =========================
    # 1. Mapping rate
    # =========================
    mr_mean = df.mapping_rate.mean()
    mr_min = df.mapping_rate.min()
    mr_max = df.mapping_rate.max()

    df.boxplot(
        column='mapping_rate',
        grid=False,
        ax=axes[0],
        boxprops=dict(linewidth=0.9),
        medianprops=dict(linewidth=1.5, color='black'),
        whiskerprops=dict(linewidth=0.9),
        capprops=dict(linewidth=0.9)
    )

    axes[0].set_ylabel('Mapping rate (%)')
    axes[0].set_xlabel(
        f"Mean {mr_mean:.2f}%\n{mr_min:.2f} ~ {mr_max:.2f}"
    )
    axes[0].set_title('Mapping rate')
    axes[0].set_xticklabels([])
    style_axis(axes[0])

    # =========================
    # 2. Average depth
    # =========================
    dp_mean = df.Average_depth.mean()
    dp_min = df.Average_depth.min()
    dp_max = df.Average_depth.max()

    df.boxplot(
        column='Average_depth',
        grid=False,
        ax=axes[1],
        boxprops=dict(linewidth=0.9),
        medianprops=dict(linewidth=1.5, color='black'),
        whiskerprops=dict(linewidth=0.9),
        capprops=dict(linewidth=0.9)
    )

    axes[1].set_ylabel('Depth (X)')
    axes[1].set_xlabel(
        f"Mean {dp_mean:.2f}X\n{dp_min:.2f} ~ {dp_max:.2f}"
    )
    axes[1].set_title('Average depth')
    axes[1].set_xticklabels([])
    style_axis(axes[1])

    # =========================
    # 3. Coverage
    # =========================
    stack_cov.boxplot(
        column='value',
        by='Coverage_X',
        grid=False,
        ax=axes[2],
        boxprops=dict(linewidth=0.9),
        medianprops=dict(linewidth=1.5, color='black'),
        whiskerprops=dict(linewidth=0.9),
        capprops=dict(linewidth=0.9)
    )

    axes[2].set_ylabel('Coverage (%)')
    axes[2].set_xlabel('')
    axes[2].set_title('Coverage')

    axes[2].set_xticklabels([
        f"1×\nMean {df.Coverage_1X.mean():.2f}%\n"
        f"{df.Coverage_1X.min():.2f} ~ {df.Coverage_1X.max():.2f}",
        f"5×\nMean {df.Coverage_5X.mean():.2f}%\n"
        f"{df.Coverage_5X.min():.2f} ~ {df.Coverage_5X.max():.2f}"
    ])

    style_axis(axes[2])

    # remove pandas auto title
    fig.suptitle('')

    plt.tight_layout()
    plt.subplots_adjust(wspace=0.35)

    out_pdf = out_dir / "BWA_QC_boxplots.pdf"
    plt.savefig(out_pdf, dpi=300)
    plt.close()

    print(f"✔ Figure saved: {out_pdf}")


def plot(df, out_dir):

    df.mapping_rate = df.mapping_rate.apply(percen_2_float)
    df.Average_depth = df.Average_depth.apply(str_2_float)
    df.Coverage_1X = df.Coverage_1X.apply(percen_2_float)
    df.Coverage_5X = df.Coverage_5X.apply(percen_2_float)
    df.Coverage_10X = df.Coverage_10X.apply(percen_2_float)

    stack_cov = df[['Coverage_1X', 'Coverage_5X']].melt(
        var_name='Coverage_X',
        value_name='value'
    )

    plot_all(df, stack_cov, out_dir)
