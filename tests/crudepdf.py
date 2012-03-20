import re

def loadxref(pdf_str):
    xrefs = loadxrefs(pdf_str)

    assert len(xrefs) == 1
    return xrefs[0]

def loadxrefs(pdf_str):
    startxref_pat = r'\r\nstartxref\r\n(\d+)\r\n%%EOF'

    xrefs = re.findall(startxref_pat, pdf_str)
    return xrefs

def loadprev(pdf_str):
    prev_pat = r'\r\ntrailer\r\n<<.*/Prev (\d+)\r\n>>\r\n'

    prev = re.findall(prev_pat, pdf_str, re.DOTALL)

    assert len(prev) == 1
    return prev[0]

def loadpageid(pdf_str):
    # very hacky - depends on reportlab comment
    page_pat = r'(\d+)\s+(\d+)\s+obj\r\n% Page dictionary'

    page = re.findall(page_pat, pdf_str, re.DOTALL)
    assert len(page) == 1

    a,b = page[0]
    return int(a), int(b)

