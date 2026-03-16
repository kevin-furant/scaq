import pandas as pd

def export_excel(data, file_path):

    df = pd.DataFrame(data)

    df.to_excel(file_path, index=False)