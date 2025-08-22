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
    return (specs, descs, errmsgs, ctxs)

