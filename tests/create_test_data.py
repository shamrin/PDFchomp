import sys
import os.path
from reportlab.pdfgen import canvas
import crudepdf

os.chdir(os.path.dirname(sys.argv[0]))

width, height = 200, 300
basic = "test_basic"
c = canvas.Canvas(basic + '.pdf', pagesize=(width, height))
c.drawString(100,100,"hello world")
c.showPage()
c.save()

content = open(basic + '.pdf','rb').read()

spec = open(basic + '.txt', 'w')
spec.write('width = %d; height = %d\n' % (width, height))
xref = int(crudepdf.loadxref(content))
spec.write('startxref = %d\n' % xref)
spec.write('pageid = %s\n' % (crudepdf.loadpageid(content), ))
