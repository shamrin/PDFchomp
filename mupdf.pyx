"""Wrapper for MuPDF"""

import sys
import os.path
from collections import namedtuple
import cStringIO # XXX use its C API instead?

def log(msg):
    sys.stderr.write('LOG: ' + msg + '\n')

# our own declarion, because there's no 'except -1' in python_string.pxd
#cdef extern int PyString_AsStringAndSize(object obj, char **buffer, Py_ssize_t *length) except -1
from python_string cimport PyString_AsStringAndSize
from python_string cimport PyString_FromStringAndSize as PyString

cdef extern from "stdlib.h":
    void* memset (void*, int, size_t)
    void* memcpy (void* dst, void* src, size_t)

cdef extern from "stdio.h":
    int printf(char *fmt, ...)

#cdef extern from "io.h":
#    int write (int, void*, unsigned int)

cdef extern from "fitz.h":
    ctypedef int fz_error

    ctypedef struct fz_buffer:
        #int refs
        #int ownsdata
        unsigned char *bp # pointer to the allocated memory
        unsigned char *rp
        unsigned char *wp
        unsigned char *ep
        int eof

    ctypedef struct fz_stream: # fitz_stream.h
        int kind
        #int dead
        fz_buffer *buffer

    ctypedef enum fz_objkind:
        FZ_NULL,
        FZ_BOOL,
        FZ_INT,
        FZ_REAL,
        FZ_STRING,
        FZ_NAME,
        FZ_ARRAY,
        FZ_DICT,
        FZ_INDIRECT

    ctypedef struct fz_obj_union_r: # fake name!
        int num
        int gen
    ctypedef union fz_obj_union: # fake name!
        int i
        float f
        fz_obj_union_r r
    ctypedef struct fz_obj:
        int refs
        fz_objkind kind
        fz_obj_union u

    ctypedef struct fz_rect:
        float x0, y0
        float x1, y1
    ctypedef struct fz_tree
    ctypedef unsigned char fz_sample
    ctypedef struct fz_pixmap:
        int x, y, w, h, n
        fz_sample *samples
    ctypedef struct fz_renderer
    ctypedef struct fz_colorspace
    ctypedef struct fz_matrix:
        pass
    ctypedef struct fz_irect:
            int x0, y0
            int x1, y1

    # stm_open.c
    fz_error fz_openrmemory(fz_stream **stmp, unsigned char *mem, int len)
    fz_error fz_openrfile(fz_stream **stmp, char *path)
    fz_error fz_openrbuffer(fz_stream **stmp, fz_buffer *buf)

    # stm_misc.c
    fz_error fz_readall(fz_buffer **bufp, fz_stream *stm, int sizehint)

    # stm_buffer.c
    fz_error fz_newbuffer(fz_buffer **bp, int size)

    # base_error.c
    fz_error fz_catch(fz_error cause, char* fmt)
    fz_error fz_throw(char* fmt)
    void fz_warn(char* fmt)

    # base_memory.c
    void fz_free(void *p) # XXX probably should never use directly

    # obj_simple.c
    fz_error fz_newint(fz_obj **op, int i)
    fz_error fz_newreal(fz_obj **op, float f)
    void fz_dropobj(fz_obj *o)     # decrement refcount
    fz_obj *fz_keepobj(fz_obj *o)  # increment refcount
    int fz_isarray(fz_obj *obj)
    float fz_toreal(fz_obj *obj)
    int fz_tonum(fz_obj *obj)
    int fz_togen(fz_obj *obj)
    fz_obj *fz_resolveindirect(fz_obj*)
    char *fz_objkindstr(fz_obj *obj)

    # obj_array.c
    fz_error fz_newarray(fz_obj **op, int initialcap)
    fz_error fz_arraypush(fz_obj *array, fz_obj *obj)
    int fz_arraylen(fz_obj *array)
    fz_obj *fz_arrayget(fz_obj *array, int i)

    # obj_dict.c
    fz_obj* fz_dictgets(fz_obj *dict, char *key)
    fz_error fz_dictputs(fz_obj *obj, char *key, fz_obj *val)
    fz_error fz_copydict(fz_obj **op, fz_obj *obj)
    fz_error fz_dictdels(fz_obj *obj, char *key)

    # obj_print.c
    int fz_sprintobj(char *s, int n, fz_obj *obj, int tight)
    void fz_debugobj(fz_obj *obj)

    # base_matrix.c
    fz_matrix fz_concat(fz_matrix one, fz_matrix two)
    fz_matrix fz_identity()
    fz_matrix fz_scale(float sx, float sy)
    fz_matrix fz_rotate(float theta)
    fz_matrix fz_translate(float tx, float ty)
    fz_irect fz_roundrect(fz_rect r)
    fz_rect fz_transformaabb(fz_matrix m, fz_rect r)

    # fitzdraw/pixmap.c
    fz_error fz_newpixmap(fz_pixmap **mapp, int x, int y, int w, int h, int n)
    void fz_droppixmap(fz_pixmap *map)

    # fitzdraw/render.c
    fz_error fz_newrenderer(fz_renderer **gcp, fz_colorspace *pcm, int maskonly, int gcmem)
    void fz_droprenderer(fz_renderer *gc)
    fz_error fz_rendertreeover(fz_renderer *gc, fz_pixmap *dest, fz_tree *tree, fz_matrix ctm)


cdef extern from "mupdf.h":
    ctypedef struct pdf_crypt
    ctypedef struct pdf_store
    ctypedef struct pdf_xrefentry:
        int ofs         # file offset / objstm object number
        int gen         # generation / objstm index
        int stmofs      # on-disk stream
        fz_obj *obj     # stored/cached object
        int type        # 0=unset (f)ree i(n)use (o)bjstm

    ctypedef struct pdf_xref: # struct in mupdf.h, typedef in fitz_stream.h
        fz_stream *file
        int startxref
        pdf_crypt* crypt
        fz_obj* info
        fz_obj* trailer
        fz_obj* root
        pdf_store* store
        int len
        int cap
        pdf_xrefentry *table
    ctypedef struct pdf_page:
        fz_rect mediabox
        int rotate
        fz_tree *tree

    # XXX *w versions for unicode in win32
    fz_error pdf_newxref(pdf_xref **)
    fz_error pdf_repairxref(pdf_xref *, char *filename)
    fz_error pdf_loadxref(pdf_xref *, char *filename)
    void pdf_closexref(pdf_xref *)

    # my functions... :-/
    fz_error pdf_baseloadxref(pdf_xref *)
    fz_error pdf_baserepairxref(pdf_xref *)

    fz_error pdf_decryptxref(pdf_xref *xref)
    int pdf_setpassword(pdf_crypt* crypt, char *pw)

    fz_error pdf_getpageobject(pdf_xref *xref, int p, fz_obj **pagep)
    fz_error pdf_getpagecount(pdf_xref *xref, int *pagesp)

    fz_error pdf_loadpage(pdf_page **pagep, pdf_xref *xref, fz_obj *ref)
    void pdf_droppage(pdf_page *page)

    fz_rect pdf_torect(fz_obj *array)

    fz_colorspace *pdf_devicergb

    void pdf_agestoreditems(pdf_store *store)
    fz_error pdf_evictageditems(pdf_store *store)


cdef extern void pdf_debugstore(pdf_store *store) # not declared in mupdf.h

DEF EOL = '\r\n'


class PDFError(Exception):
    """Error when reading/writing/rendering PDF"""

class InternalError(Exception):
    """Some internal error"""


cdef class Object(object):
    """Base class for PDF objects"""
    cdef fz_obj *obj

    def __dealloc__(self):
        if self.obj != NULL:
            fz_dropobj(self.obj)

    def str(self): # cdef?, __str__?
        #obj = fz_resolveindirect(self.obj)
        DEF bufsize = 1024
        cdef char buf[bufsize]
        cdef int n
        n = fz_sprintobj(buf, bufsize-1, self.obj, 0)
        if n >= bufsize - 1:
            raise InternalError('buffer too small?')
        return buf


cdef class Integer(Object):

    def __cinit__(self, n=0, allocate=True, *args, **kw):
        if allocate:
            if not isinstance(n, (int, long)): # XXX should check overflow
                raise TypeError('an integer is required')
            if fz_newint(&self.obj, n):
                raise PDFError("cannot create new integer")

    def __repr__(self):
        return 'Integer(%d)' % self.obj.u.i

    def __str__(self):
        return '%d' % self.obj.u.i


cdef class Real(Object):

    def __cinit__(self, f=0.0, allocate=True, *args, **kw):
#        print 'Real.__cinit__(allocate=%s)' % allocate, 'f =', f
        if allocate:
            if fz_newreal(&self.obj, f):
                raise PDFError("cannot create new real")

#    def __dealloc__(self): 
#        print 'Real.__dealloc__', (str(self.obj.u.f) if self.obj else '')

    def __repr__(self): 
        # XXX %s gives rubbish (see bbox to fix)
        return 'Real(%f)' % fz_toreal(self.obj)

    def __str__(self):
        return '%f' % fz_toreal(self.obj)

cdef class Array(Object):

    def __cinit__(self, elems=None, allocate=True, *args, **kw):
#        print 'Array.__cinit__'
        if allocate:
            if elems is None:
                elems = []
            if fz_newarray(&self.obj, len(elems)):
                raise PDFError("cannot create new array")
            for elem in elems:
                if fz_arraypush(self.obj, (<Real>Real(elem)).obj):
                    raise PDFError("cannot push to array")

#    def __dealloc__(self): print 'Array.__dealloc__'

    def __iter__(self):
        cdef int i
        cdef fz_obj *obj
        elems = []
        for i in range(fz_arraylen(self.obj)):
            obj = fz_arrayget(self.obj, i)
            if not obj:
                raise PDFError("cannot get from array")
            elems.append(wrapobj(obj))
        return iter(elems)

    def __repr__(self):
        return 'Array([%s])' % ', '.join([repr(e) for e in self])

    def __str__(self):
        return 'Array([%s])' % ', '.join([str(e) for e in self])


cdef class Dictionary(Object):

    def copy(self):
        cdef fz_obj *newobj
        if fz_copydict(&newobj, self.obj):
            raise PDFError('cannot copy dict')

        cdef Dictionary d = Dictionary(allocate=False)
        d.obj = newobj # fz_keepobj not needed, because fz_copydict called it

        return d

    def __setitem__(self, key, Object obj):
        if fz_dictputs(self.obj, key, obj.obj):
            raise PDFError('cannot set dict item')


cdef object initkind = {
    # these classes should honour `allocate` parameter when having __cinit__
    FZ_INT: Integer,
    FZ_REAL: Real,
    FZ_ARRAY: Array,
    FZ_DICT: Dictionary,
}

cdef Object wrapobj(fz_obj *obj):
    """Wrap fz_obj* with a suitable Object subclass"""

    # @classmethod & @staticmethod don't work for cdef methods...

    obj = fz_resolveindirect(obj) # XXX do it ealier? (when called in Page)
    try:
        init = initkind[obj.kind]
    except KeyError:
        raise NotImplementedError('cannot wrap "%s" obj' % fz_objkindstr(obj))
    cdef Object o = init(allocate=False)
    o.obj = fz_keepobj(obj)
    return o


cdef class Renderer(object):
    """Wrapper for fz_renderer"""

    cdef fz_renderer *drawgc

    def __cinit__(self):
#        print 'Renderer.__cinit__'
        self.drawgc = NULL
        if fz_newrenderer(&self.drawgc, pdf_devicergb, 0, 1024*512):
            raise PDFError('Cannot create Renderer')

    def __dealloc__(self):
#        print 'Renderer.__dealloc__'
        if self.drawgc:
            fz_droprenderer(self.drawgc)
            self.drawgc = NULL


# Attributes are roughly compatible with attributes of pyglet.image.ImageData
ImageData = namedtuple('ImageData', 'width height format pitch data')

cdef class PDF(object)
cdef class Xref(object)

cdef class Page(object):
    """Page in PDF file
    
    Do not create directly; instead use PDF.__getitem__ or iterate over PDF()
    """

    cdef fz_obj* page
    cdef pdf_xref *xref
    cdef object pdf
    cdef int pagenum

    # Have to keep reference here, otherwise self.page would (sometimes?) 
    # point to garbage after update
    cdef Xref _save_xref

    def object_id(self): # XXX cpdef?
        """Return (object_number, generation_number) of this page's object"""
        return fz_tonum(self.page), fz_togen(self.page)

    def __cinit__(self):
        pass # XXX

    def __dealloc__(self):
        pass # XXX

    def __init__(self, PDF pdf, pagenum):
        self.pdf = pdf
#        self.xref = pdf.xref
        self._save_xref = pdf.xref # see above
        self.xref = pdf.xref.xref
        self.pagenum = pagenum
        if pdf_getpageobject(self.xref, pagenum, &self.page):
            raise PDFError('cannot load page object')

    def __repr__(self):
        return '<Page %d at 0x%X of %r>' % (self.pagenum, id(self), self.pdf)

    property bounds:

        def __get__(self):
            cdef fz_obj* obj = fz_dictgets(self.page, "MediaBox")
            if not fz_isarray(obj):
                raise PDFError('error loading MediaBox')
            cdef fz_rect bbox = pdf_torect(obj)
            return bbox.x0, bbox.y0, bbox.x1, bbox.y1

        def __set__(self, new_bounds):
            self.pdf.updatepage(self, "MediaBox", Array(new_bounds))
            # XXX write CropBox only when it is already defined
            self.pdf.updatepage(self, "CropBox", Array(new_bounds))

    def image_buffer(self, format):
        # "constants"
        cdef float drawzoom = 1.0
        cdef float drawrotate = 0.0
        cdef int drawbands = 1

        cdef pdf_page *drawpage

        cdef Renderer renderer = self.pdf.getrenderer()

        if pdf_loadpage(&drawpage, self.xref, self.page): # dropped below
            raise PDFError('Cannot load page')

        cdef fz_matrix ctm = fz_identity()
        ctm = fz_concat(ctm, fz_translate(0, -drawpage.mediabox.y1))
        ctm = fz_concat(ctm, fz_scale(drawzoom, -drawzoom))
        ctm = fz_concat(ctm, fz_rotate(drawrotate + drawpage.rotate))

        cdef fz_irect bbox 
        bbox = fz_roundrect(fz_transformaabb(ctm, drawpage.mediabox))
        cdef int w = bbox.x1 - bbox.x0
        cdef int h = bbox.y1 - bbox.y0
        cdef int bh = h / drawbands

        #f = open('test.ppm', 'wb')
        header = 'P6\n%d %d\n255\n' % (w, h)
        #write(f.fileno(), <char*>header, len(header))

        cdef fz_pixmap *pix
        if fz_newpixmap(&pix, bbox.x0, bbox.y0, w, bh, 4): # dropped below
            raise PDFError('Cannot create pixmap')

        memset(pix.samples, 0xff, pix.h * pix.w * pix.n)

        cdef int b

        cdef unsigned char *p
        cdef unsigned char swap
        cdef int i

        for b in range(drawbands):
            if drawbands > 1:
                log("drawing band %d / %d" % (b + 1, drawbands))

            if fz_rendertreeover(renderer.drawgc, pix, drawpage.tree, ctm):
                raise PDFError('Cannot render tree')

            # original format is ARGB
            if format == 'ARGB':
                pass # nothing to do
            elif format == 'BGRA':
                for i in range(pix.h*pix.w):
                    p = pix.samples + i * 4
                    swap = p[0]; p[0] = p[3]; p[3] = swap
                    swap = p[1]; p[1] = p[2]; p[2] = swap
            elif format == 'RGBA':
                for i in range(pix.h*pix.w):
                    p = pix.samples + i * 4
                    swap = p[0]; 
                    p[0] = p[1]; p[1] = p[2]; p[2] = p[3] # shift left
                    p[3] = swap
            else:
                raise PDFError('Image format not supported: %s' % format)

            # XXX provide object with buffer interface instead
            img_data = PyString(<char *>pix.samples, pix.h * pix.w * pix.n)

            pix.y += bh
            if pix.y + pix.h > bbox.y1:
                pix.h = bbox.y1 - pix.y

        fz_droppixmap(pix) # XXX ensure it's called in any case
        #f.close()
        pdf_droppage(drawpage) # XXX ensure it's called in any case
        # XXX flush xref.store (see pdfdraw.c:drawfreepage and :local_cleanup)
        #pdf_debugstore(self.xref.store)

        return ImageData(width=w, height=h, format=format, 
                         pitch=-w*len(format), data=img_data)

    def image_PIL(self):
        """Return PIL image of the page"""

        try:
            import Image
        except ImportError:
            raise ImportError('Cannot import Image module. Install PIL.')

        im = self.image_buffer('RGBA')
        return Image.fromstring(im.format, (im.width, im.height), im.data)

    def image_GDI(self):
        """Return ImageData instance for use in GDI+
        
        ImageData is roughly compatible with pyglet.image.ImageData
        """

        # MSDN says GDI+ supports 'ARGB', but it's in fact 'BGRA' because of 
        # Intel little-endianness
        return self.image_buffer('BGRA')

    def str_changed(self, changes): # XXX return new Page instead of str?
        newpage = wrapobj(self.page).copy()
        for dict_key, dict_val in changes:
            newpage[dict_key] = dict_val

        return '\n'.join(['%d %d obj' % self.object_id(),
                          newpage.str(), 
                          'endobj', 
                          '']).replace('\n', EOL)

    def str4xref(self, offset=None):
        cdef int num, gen
        num, gen = self.object_id()
        cdef pdf_xrefentry *entry = &self.xref.table[num]

        if offset is None:
            offset = entry.ofs

        head = '%d 1' % num # XXX merge consecutive objects for disk-space...
        sentry = '%010d %05d %s' % (offset, entry.gen, chr(entry.type))
        return EOL.join([head, sentry, ''])

def obj_getnum(obj): return (<fz_obj*?>obj).u.r.num


# XXX put into Memory class
cdef int str2buffer(str s, unsigned char *buffer, int maxlen) except -1:
    """Write string content to buffer and return number of bytes written."""

    cdef Py_ssize_t strlen
    cdef char *strbuf
    # XXX maybe off-by-one error - '\0' at the end?
    if PyString_AsStringAndSize(s, &strbuf, &strlen) == -1:
        # XXX already raises TypeError - check if raising PDFError is okay
        raise PDFError('PyString_AsStringAndSize failed')

    assert strlen < maxlen
    memcpy(buffer, strbuf, strlen)

    return strlen


cdef class Memory(object):
    """Memory buffer, initialized from string"""

    DEF MEMSIZE = 2 * 10**6 # XXX ouch! - change to malloc!
    cdef unsigned char mem[MEMSIZE]
    cdef Py_ssize_t baselen # XXX change to int?
    cdef Py_ssize_t len

    def __cinit__(self, source, *args, **kw):
        if isinstance(source, str):
            self.baselen = self.len = str2buffer(source, self.mem, MEMSIZE)
        else:
            # XXX should probably support: filename, Py buffer
            raise NotImplementedError('Cannot create Memory from object '
                                      'of type "%s"' % type(source))

    def __dealloc__(self):
        # XXX free!
        pass

    property length:
        def __get__(self):
            return self.len

    def extend(self, s):
        """Extend memory buffer with string content"""

        appended = str2buffer(s, self.mem + self.len, 
                                 MEMSIZE - self.len)
        self.len += appended

#        appended = str2buffer(s, self.mem + self.baselen, 
#                                 MEMSIZE - self.baselen)
#        self.len = self.baselen + appended

    def tostr(self):
        """Return string with current memory buffer content"""
        return PyString(<char *>self.mem, self.len)


cdef class Xref(object):
    """Wrapper for MuPDF pdf_xref structure"""

    cdef pdf_xref *xref
    cdef int numpages
    cdef Memory memory

    cdef int initfrommemory(self) except -1:
        # XXX free?
        if fz_openrmemory(&self.xref.file, 
                          self.memory.mem, self.memory.len):
            raise PDFError('Cannot create buffer from memory')

        #log('stream: kind=%d' % self.xref.file.kind)
        #cdef fz_buffer *b = self.xref.file.buffer
        #log('buffer: bp=%d, rp=%d, wp=%d, ep=%d, eof=%d' % 
        #        (<int>b.bp, <int>b.rp, <int>b.wp, <int>b.ep, b.eof))

        if pdf_baseloadxref(self.xref):
            log("ERROR: load failed - trying to repair")
            if pdf_baserepairxref(self.xref):
                raise PDFError('Cannot load in-memory file')

    def __cinit__(self, source, password="", *args, **kw):

        if pdf_newxref(&self.xref):
            raise PDFError('Cannot allocate xref')

        if isinstance(source, Memory):
            self.memory = source # keep reference to prevent deallocation
            self.initfrommemory()
        elif isinstance(source, str): # filename
            raise NotImplementedError('Cannot create Xref from filename')
            # <OLD>
            #if pdf_loadxref(self.xref, filename):
            #    log("trying to repair")
            #    if pdf_repairxref(self.xref, filename):
            #        raise PDFError('Cannot open file: %s' % filename)
            # </OLD>
        else:
            raise PDFError('Cannot create Xref from %s object' % type(source))

        # <OLD STUFF FROM HERE>
        if pdf_decryptxref(self.xref):
            raise PDFError('Cannot decrypt file')

        cdef int dieonbadpass = 0 # XXX get rid of it?
        cdef int okay
        if (self.xref.crypt):
            okay = pdf_setpassword(self.xref.crypt, password)
            if (not okay and not dieonbadpass):
                print "invalid password, attempting to continue."
            elif (not okay and dieonbadpass):
                raise PDFError('Invalid password')

        cdef fz_obj *obj
        obj = fz_dictgets(self.xref.trailer, "Root")
        self.xref.root = fz_resolveindirect(obj)
        if (self.xref.root):
            fz_keepobj(self.xref.root)

        obj = fz_dictgets(self.xref.trailer, "Info")
        self.xref.info = fz_resolveindirect(obj)
        if (self.xref.info):
            fz_keepobj(self.xref.info)

        if pdf_getpagecount(self.xref, &self.numpages):
            raise PDFError('Cannot get page count')

    def __dealloc__(self):
        if self.xref != NULL:
            pdf_closexref(self.xref)
            #log('xref {0} closed'.format(self.filename))

    cdef Dictionary trailer(self):
        return wrapobj(self.xref.trailer)


cdef class PDF(object):
    """PDF file
    
    >>> pdf = PDF('eat.pdf')
    >>> len(pdf)
    58
    >>> pdf[0].bounds # retrieve MediaBox of the first page
    (0.0, 0.0, 595.0, 842.0)

    Iterate over all pages:
    >>> for page in pdf: #doctest: +ELLIPSIS
    ...     print page.bounds
    (0.0, 0.0, 595.0, 842.0)
    (0.0, 0.0, 595.0, 842.0)
    ...
    """

    cdef Xref xref
    cdef int pagecounter
    cdef object filename
    cdef object pages_changes
    cdef Renderer renderer
    cdef readonly str password
    cdef Memory memory
    cdef readonly int prev_startxref

    property startxref:
        def __get__(self):
            return self.xref.xref.startxref

    def __init__(self, filename, password=""):
#        #log("__init__({0})".format(filename))
        self.pagecounter = 0
        self.filename = filename
        self.password = password
        self.memory = Memory(open(filename, 'rb').read())
        try:
            self.xref = Xref(self.memory, password=password)
        except PDFError, err:
            raise PDFError('Cannot open file: %s (%s)' % (filename, err))
        self.prev_startxref = self.startxref
        self.pages_changes = {} # XXX OrderedDict instead?

    def __repr__(self):
        return '<PDF "%s" at 0x%X>' % (self.filename, id(self))

    def __iter__(self):
        return self

    def __next__(self):
        if self.pagecounter >= self.xref.numpages:
            raise StopIteration
        page = Page(self, self.pagecounter)
        self.pagecounter += 1
        return page

    def __len__(self):
        return self.xref.numpages

    def __getitem__(self, pagenum):
        return Page(self, pagenum)

    def getrenderer(self):
        if self.renderer is None:
            self.renderer = Renderer()
        return self.renderer

    def updatepage(self, page, dict_key, dict_val):
        self.pages_changes.setdefault(page, []).append((dict_key, dict_val))

    def updates(self, filesize, prev):          # XXX convert to a function 
        """Return (new startxref, pending updates string) tuple

        filesize - size of original file
        prev - original startxref address
        """

        if not self.pages_changes:
            return prev, ''

        f = cStringIO.StringIO()

        # write objects
        offsets = {}
        for page, changes in self.pages_changes.items():
            f.write(EOL)
            offsets[page] = f.tell() + filesize
            f.write(page.str_changed(changes))

        # write xref
        startxref = f.tell() + filesize
        f.write('xref' + EOL)

#        cdef pdf_xrefentry *entry = &self.xref.table[0]
        cdef pdf_xrefentry *entry = &self.xref.xref.table[0]
        triple = entry.ofs, entry.gen, chr(entry.type)
        if triple != (0, 65535, 'f'):
            raise PDFError('Unexpected first xref entry: %s' % triple)
        f.write('0 1' + EOL)
        f.write(('%010d %05d %s' % triple) + EOL)

        for page in sorted(self.pages_changes, key=obj_getnum):
            s = page.str4xref(offset=offsets[page])
            f.write(s)

        # write trailer
        trailer = self.xref.trailer().copy()
        trailer['Prev'] = Integer(prev)
        f.write('\n'.join(['trailer', trailer.str(), '']).replace('\n', EOL))

        # write startxref
        f.write('\n'.join(['startxref', 
                           str(startxref), 
                           '%%EOF']).replace('\n', EOL))

        return startxref, f.getvalue()

    def fastsave(self, file):
        """Incrementally save PDF file with pending updates to file
        
        `file` - a file-like object (with `write` method), or just a filename
        """

        opened_here = False
        try:
            file.write
        except AttributeError:
            file = open(file, 'wb')
            opened_here = True

        try:
            file.write(self.memory.tostr())
            start, upd = self.updates(self.memory.length, self.prev_startxref)
            file.write(upd)
        finally: # XXX is it really needed?
            if opened_here:
                file.close()

    def memorysave(self): # XXX rename to `commit`, `recordchanges` or ... ?
        """Save pending updates to memory and re-parse in-memory PDF file"""

        start, upd = self.updates(self.memory.length, self.prev_startxref)
        self.memory.extend(upd)
        self.prev_startxref = start
        self.pages_changes = {}
        self.xref = Xref(self.memory, password=self.password)

#    def reload(self):
#        """Reload PDF file from memory buffer - for debugging only"""
#
#        self.loadmemory()

    def memorycontent(self):
        """Return current memory content as a string (mainly for debugging)"""

        # WARNING! Windows console hangs when printing arbitrary data to it.

        return self.memory.tostr()

