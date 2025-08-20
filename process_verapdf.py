import subprocess
import sys
import re

def safe_reg(pattern, text):
    res = re.search(pattern, text)
    if res == None:
        return "failed"
    else:
        return res.group(1)

def reg_name(text):
    pattern = r"<name>(.*?)</name>"
    return safe_reg(pattern, text)
    # res = re.search(pattern, text)
    # return res.group(1)

def reg_failed_rules(text): 
    pattern = r'failedRules="(.*?)"'
    if safe_reg(pattern, text) == "failed":
        return "0"
    else:
        return safe_reg(pattern, text)
    # res = re.search(pattern, text)
    # return res.group(1)

def reg_rules(text):
    pattern_spec = r'rule specification="(.*?)"'
    pattern_desc = r"<description>(.*?)</description>"
    pattern_errmsg = r"<errorMessage>(.*?)</errorMessage>"
    pattern_ctx = r"<context>(.*?)</context>"
    specs = re.findall(pattern_spec, text)
    descs = re.findall(pattern_desc, text)
    errmsgs = re.findall(pattern_errmsg, text)
    ctxs = re.findall(pattern_ctx, text)
    return [specs, descs, errmsgs, ctxs]

def main():
    filepath = sys.argv[1]
    profile = sys.argv[2]
    cmd = f'verapdf -f {profile} {filepath}'
    proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
    output = proc.stdout.read().decode('utf-8')
    print(f'Filename: {reg_name(output)}')
    failed_rules = int(reg_failed_rules(output))
    print(f'Failed Rules: {failed_rules}\n')
    matches = reg_rules(output)
    for a in range(failed_rules):
        # print(f'Spec: {matches[0][a]}')
        print(f'Desc: {matches[1][a]}')
        # print(f'Ctx: {matches[3][a]}')
        print(f'ErrMsg: {matches[2][a]}\n')

if __name__ == "__main__":
    main()
