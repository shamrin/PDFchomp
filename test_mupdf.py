import os
import sys
from itertools import islice
#os.environ['MULOG'] = 'a' # debug mupdf
import mupdf

pdfname = 'Nissan_NOTE.pdf'
pdf = mupdf.PDF(pdfname)
pages = list(pdf)
print 'pages', len(pages)
for i, page in enumerate(islice(pages,10)):
#    print page.mediabox()
    img = page.image_PIL()
    pngname = '%s%02d.png' % (pdfname.rpartition('.')[0], i)
    try:
        os.remove(pngname)
    except (WindowsError, IOError):
        pass
    img.save(pngname)
    print i+1,
#print pdf.next().mediabox()
sys.exit()

for name in ['eat.pdf', 'Nissan_NOTE.pdf', 'hello_world.pdf', 'nothing.pdf']:
    pdf = mupdf.PDF(name)
    np = pdf.numpages()
    print name, np
    for n in [0]:#range(np): 
        print '{0:2}'.format(n+1), pdf.getmediabox(n)
