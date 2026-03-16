import pandas as pd

def parse_file(file):

    if file.filename.endswith(".xlsx"):

        df = pd.read_excel(file.file)

    elif file.filename.endswith(".txt"):

        df = pd.read_csv(file.file, sep="\t")

    else:

        raise Exception("unsupported file")

    df["时间"] = pd.to_datetime(df["时间"])

    df["year"] = df["时间"].dt.year

    df = df.rename(columns={
        "时间": "time",
        "批次名": "batch_name",
        "样本名": "sample_name",
        "数据路径": "data_path"
    })

    records = df[[
        "year",
        "time",
        "batch_name",
        "sample_name",
        "data_path"
    ]]

    return records.to_dict("records")