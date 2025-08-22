import subprocess, os
from pathlib import Path
from .filter_verapdf import reg_name, reg_rules, reg_failed_rules

# run_exec: simple wrapper for subprocess.run 
# (use stdin and stdout properties)
def run_exec (cmd):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', shell=False)

# exec_pdfaer: executes pdfaer.exe command taken as input
# and returns the filepath of the generated pdf pdfafile to check.
# cmd: [a, b, c, ...],
def exec_pdfaer (cmd):
    ret = run_exec(cmd)
    return_path = None
    for i, token in enumerate(cmd):
        if token in ('-o', '-out', '-output'):
            if i + 1 < len(cmd):
                return_path = Path(cmd[i+1]).resolve()
        break

    if return_path is None:
        input_pdf = next((Path(t) for t in cmd if isinstance(t, str) and t.lower().endswith(".pdf")), None)
        if input_pdf is None:
            raise ValueError("exec_pdfaer: could not determine output path (no -o/--out and no .pdf arg).")
        return_path = Path(os.getcwd()) / f"{input_pdf.stem}_pdfa.pdf"

    return str(return_path)



# verify_pdf: uses verapdf on the file given in the command, returning
# a string of the filtered (regex) verapdf output.
def verify_pdf (cmd):
    ret = run_exec(cmd)
    if ret is None:
        raise RuntimeError(f"verify_pdf: cmd: {cmd}")
    text = (ret.stdout or "") if ret is not None else ""

    pdf_name = Path(reg_name(text))
    failed = reg_failed_rules(text)
    specs, descs, errmsgs, ctxs = reg_rules(text)

    lines = [f"failedRules={failed}"]

    if failed != "0":
        n = min(len(specs), len(descs), len(errmsgs), len(ctxs))
        for i in range(n):
            lines.append(f"\n|  {specs[i]}\n|  {descs[i]}\n|  {errmsgs[i]}\n|  ctx={ctxs[i]}")

    return "\n".join(lines)


    

