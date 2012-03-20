**This project is currently DEAD. I found it looking through my old files. Worked on it in September 2009.**

## PDFchomp: graphical PDF editor

![PDFchomp screenshot](PDFchomp/raw/master/screenshort.jpg)

PDFchomp is an open source (GPL) PDF editor with a Python API. In the last version you could open PDF file, choose a crop rectangle with a mouse and save the cropped file.

PDFchomp depends on an open source [MuPDF][] library (used by very nice PDF viewer [SumatraPDF][]). The library is in C, so I wrapped it with [Cython][], and added basic capabilities for PDF editing. The result is a Python module `mupdf`, which can be used this way:

```python
>>> pdf = mupdf.PDF('some_file.pdf')
>>> len(pdf) # number of pages
58
>>> pdf[0].bounds # first page bounds (MediaBox)
(0.0, 0.0, 595.0, 842.0)

Iterate through pages
>>> for page in pdf: print page.bounds
(0.0, 0.0, 595.0, 842.0)
(0.0, 0.0, 595.0, 842.0)
...

Cut 10 pixels from each edge and save changes to file
>>> pdf[0].bounds = (10, 10, 585, 585)
>>> pdf.fastsave('cropped_file.pdf')
```

Graphical interface is implemented in Python using [PyGUI][] library.

Final binary works on Windows. Porting to Mac OS X and Linux shouldn't be
very difficult - all libraries are cross-platform.

[MuPDF]: http://ccxvii.net/mupdf/
[SumatraPDF]: http://blog.kowalczyk.info/software/sumatrapdf
[Cython]: http://www.cython.org/
[PyGUI]: http://www.cosc.canterbury.ac.nz/greg.ewing/python_gui/
