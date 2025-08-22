import sys
from pathlib import Path
from datetime import datetime

try:
    from .exec_tools import exec_pdfaer, verify_pdf, run_exec
    from .filescript import get_icc_path, get_exec_path
except ImportError as e:
    print("[error], __main__.py: import failed. ", e, file=sys.stderr)
    exit(1)

DIR = Path(__file__).parent.resolve()
ROOT = DIR.parent
OPATH = ROOT / 'outfiles'
IPATH = ROOT / 'infiles'
LPATH = ROOT / 'logs'

def ensure_dirs(opath:Path, lpath:Path, ipath:Path) -> None:
    opath.mkdir(parents=True, exist_ok=True)
    ipath.mkdir(parents=True, exist_ok=True)
    lpath.mkdir(parents=True, exist_ok=True)

def convert (exe_path:Path) -> list[Path]:
    outs : list[Path] = []
    for f in sorted(IPATH.glob('*.pdf')):
        out = OPATH / f'{f.stem}_pdfa.pdf'
        cpdf_decompress_cmd = ['cpdf', '-decompress', str(f)]
        pdfa_cmd = [exe_path, str(f), '-o', str(out)]
        try:
            run_exec(cpdf_decompress_cmd)
            done = Path(exec_pdfaer(pdfa_cmd))
            outs.append(done)
            print(f'[converted]: {f.name}')
        except Exception as e:
            print(f'[converted][error]: {e}')
    return outs

def verify (opath:Path, pdfa_flavor:str) -> str:
    pdfalist = sorted(opath.glob('*_pdfa.pdf'))
    res_stanzas : list[str] = []
    for pdfa in pdfalist:
        cmd = ['verapdf', '--format', 'mrr', '-f', pdfa_flavor, str(pdfa)]
        try:
            res = verify_pdf(cmd)
        except Exception as e:
            res = f'name={pdfa.name}\nfailedRules=ERR\n- exception={e}'
        head = f'==== {pdfa.name} ===='
        res_stanzas.append('\n'.join([head, res, '']))
        print(f'[verified]: {pdfa.name}')
    return '\n'.join(res_stanzas)


def main ():
    ensure_dirs(OPATH, LPATH, IPATH)

    pdfaer_path = get_exec_path()
    if pdfaer_path is None:
        print(f'[error] __main__.py main: error retrieving pdfaer.exe path')
        exit(1)

    convert(Path(pdfaer_path))
    report = verify(OPATH, '1b')

    ts = datetime.now().strftime('%S:%M:%H_%m-%d-%Y')
    logfile = LPATH / f'log_{ts}.log'
    logfile.write_text(report, encoding='utf-8')
    print(f'[logged]: {logfile}')

    exit(0)

if __name__ == '__main__':
    main()
