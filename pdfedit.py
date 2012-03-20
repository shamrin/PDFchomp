"""Simple PDF editor based on mupdf module"""

import ctypes

from GUI import (Application, ScrollableView, Document, Window, FileType, Cursor, Image, Frame, Label, Button)
from GUI.Geometry import (pt_in_rect, offset_rect, rects_intersect,
                          rect_width, rect_height, add_pt, 
                          rect_sized, rect_topleft, 
                          rect_botright, rect_size,
                          rect_top, rect_bottom, rect_left, rect_right)
from GUI.StdColors import black, red, rgb
from GUI.StdCursors import (sizer_nw_se, sizer_ne_sw, sizer_w_e, sizer_n_s,
                            crosshair, finger)

import mupdf

# XXX move My* classes functionality to PyGUI

# For this to work, comment out `raise` in GUI.Win32.__init__.py.
from GUI.Win32.GDIPlus import Bitmap as GDIBitmap, wg as gdiplus
PixelFormat32bppARGB = 2498570 # from pyglet.image.codecs.gdiplus.py

class MyGDIBitmap(GDIBitmap):
    @classmethod
    def from_image(cls, image):
        self = cls.__new__(cls)
        ptr = ctypes.c_void_p()
        self._create_from_image(image, ptr) 
        self.ptr = ptr
        return self

    def _create_from_image(self, image, ptr):
        if image.format != 'BGRA':
            raise Exception('Image format not supported: %s' % image.format)
        format = PixelFormat32bppARGB # 'BGRA' really (Intel little-endianness)

        if image.pitch >= 0:
            raise Exception('Image pitch not supported: %d' % image.pitch)
        stride = abs(image.pitch)
        if stride < image.width * len(image.format):
            raise Exception('Image pitch truncates image: %d' % image.pitch)

        gdiplus.GdipCreateBitmapFromScan0(image.width, image.height, 
                                          stride, format,
                                          image.data,
                                          ctypes.byref(ptr))

class MyImage(Image):
    def __init__(self, image):
        # attributes of `image` mean the same as of pyglet.image.ImageData 
        self._init_from_image(image)

    def _init_from_image(self, image):
        self._win_image = MyGDIBitmap.from_image(image)


def hide(component):
    """Hide component -- to work-around (win32 only?) bug"""

    component.hide()
    component.container.invalidate_rect(component.bounds) # force repaint!


class PDFEditor(Application):

    def __init__(self):
        Application.__init__(self)
        self.pdf_type = FileType(name="PDF Document", suffix="pdf", 
            #mac_creator = "BLBE", mac_type = "BLOB", # These are optional
        )
        self.file_type = self.pdf_type
#        self.blob_cursor = Cursor("blob.tiff")
    
    def open_app(self):
#        self.new_cmd()
        self.open_cmd() # or big "Open" button

    def make_document(self, fileref):
        return PDFDoc(file_type=self.pdf_type)

    def make_window(self, document):
        win = Window(size=(700, 500), document=document)

        panel = Frame(width=170)

        def crop_action():
            if view.selection is None:
                view.setselection(shrink_rect(view.viewrect, 0.8))
                return

            croprect = view.pdfcoord(view.selection)
            #print 'view: %s, crop: %s' % (view.selection, croprect)
            view.model.crop(view.pagenum, croprect)
            view.selection = None
            view.set_status(selection=None)
            hide(view.crop_button)

        crop_button = Button(title='Crop', visible=True, action=crop_action)
        status = Label(text='\n\n\n\n')

        view = PDFView(pagenum=0, model=document, scrolling='hv',
                       status=status, cursor=crosshair, crop_button=crop_button)
        #view = PDFView(... extent=(1000, 1000), cursor = self.blob_cursor)

        def page_changer(delta):

            def change():
                np = win.document.numpages
                view.pagenum += delta

                if view.pagenum <= 0:
                    view.pagenum = 0
                    prevpage.enabled = False
                else:
                    prevpage.enabled = True

                if view.pagenum >= np - 1:
                    view.pagenum = np - 1
                    nextpage.enabled = False
                else:
                    nextpage.enabled = True

                page.text = '%s / %s' % (view.pagenum+1, np)
                view.invalidate()

            return change

        prevpage = Button(title='<', action=page_changer(-1))
        nextpage = Button(title='>', action=page_changer(+1))
        page = Label(just='center', anchor='b')
        page_changer(0)()

        panel.place(prevpage, top=5, left=5, sticky='w')
        panel.place(nextpage, top=5, right=-5, sticky='e')
        panel.place(page, bottom=prevpage.bottom, 
                    left=prevpage, right=nextpage, sticky='ew')

        panel.place(status, left=5, top=prevpage+5, right=0, sticky='ew')
        panel.place(crop_button, left=5, top=status, right=-5, sticky='ew')

        win.place(panel, left=0, top=0, bottom=0, sticky='nsw')
        win.place(view, left=panel, top=0, right=0, bottom=0, sticky='nsew')
        win.shrink_wrap()
        win.show()


def rect_larger(rect, d):
    left, top, right, bottom = rect
    dx, dy = d
    return left-dx, top-dy, right+dx, bottom+dy


def clamp_rect(rect, limits, keepsize=False):

    def confine(Rmin, Rmax, Lmin, Lmax):
        if Rmin < Lmin:
            if keepsize:
                Rmax += Lmin - Rmin
            Rmin = Lmin
        if Rmax > Lmax:
            if keepsize:
                Rmin -= Rmax - Lmax
            Rmax = Lmax
        return Rmin, Rmax

    left, top, right, bottom = rect

    left, right = confine(left, right, rect_left(limits), rect_right(limits))
    top, bottom = confine(top, bottom, rect_top(limits), rect_bottom(limits))

    return left, top, right, bottom


def confine_rect(rect, limits):
    return clamp_rect(rect, limits, keepsize=True)


def shrink_rect(rect, ratio):
    left, top, right, bottom = rect
    k = (1 - ratio) / 2.0
    w, h = rect_size(rect)

    left += k * w
    right -= k * w
    top += k * h
    bottom -= k * h

    return int(left), int(top), int(right), int(bottom)


def interpolate(x, x0, x1, y0, y1):
    return int(round((x - x0) * (y1 - y0) / (float(x1) - x0) + y0))


def hexrgb(r,g,b): return rgb(r/255.0, g/255.0, b/255.0)
bordercolor = hexrgb(0x88, 0x88, 0x88)
shadowcolor = hexrgb(0x44, 0x44, 0x44)
backcolor = hexrgb(0xcc, 0xcc, 0xcc)

top_dx, top_dy = 3, 3
shadow_dx, shadow_dy = 4, 4

class PDFView(ScrollableView):

    def __init__(self, pagenum, status, crop_button=None, *args, **kw):
        ScrollableView.__init__(self, *args, **kw)
        self.pagenum = pagenum
        self.crop_button = crop_button
        self.selection = None
        self.status = status
        self.status_info = dict(mouse=None, selection=None)

    def pdfpoint(self, point):
        """Translate point from View coordinates to PDF coordinates"""

        def interpolate_coord(coord, rect_first, rect_last):
            vr = self.viewrect
            pr = self.pdfrect
            return interpolate(coord, rect_first(vr), rect_last(vr),
                                      rect_first(pr), rect_last(pr))
        def interpolate_x(coord):
            return interpolate_coord(coord, rect_left, rect_right)
        def interpolate_y(coord):
            return interpolate_coord(coord, rect_top, rect_bottom)

        x, y = point
        return interpolate_x(x), interpolate_y(y)

    def pdfcoord(self, viewrect):
        """Translate rect from View coordinates to PDF coordinates"""

        left, top, right, bottom = viewrect

        pdfrect = self.pdfpoint((left, bottom)) + self.pdfpoint((right, top))

        #print 'pdfcoord: %s => %s' % (viewrect, pdfrect)
        return pdfrect

    def set_status(self, **kw):
        """Set status information"""

        info = self.status_info

        for key in ('mouse', 'selection'):
            try:
                val = kw[key]
            except KeyError:
                pass
            else:
                info[key] = val
            
        text = ''
        if info['mouse'] is not None:
            text += 'Mouse: %d, %d\n' % info['mouse']
        if info['selection'] is not None:
            text += 'Selection:\n  (%d, %d) -\n  (%d, %d)' % info['selection']

        self.status.text = text

    def draw(self, canvas, update_rect):
        canvas.backcolor = backcolor
        canvas.erase_rect(update_rect)

        self.pdfrect, im = self.model.pageimage(self.pagenum)
        if im is None:
            return
        self.image = image = MyImage(image = im)

        self.viewrect = (top_dx + 1, top_dy + 1,
                         top_dx + 1 + image.width, top_dy + 1 + image.height)

        dest = offset_rect(image.bounds, (top_dx, top_dy))
        frame = rect_larger(dest, (1,1))

        # draw shadow (XXX draw only lower right part of it)
        canvas.pencolor = canvas.fillcolor = shadowcolor
        canvas.fill_frame_rect(offset_rect(frame, (shadow_dx, shadow_dy)))

        # draw frame
        canvas.pencolor = bordercolor
        canvas.frame_rect(frame)

        self.extent = (image.width + top_dx + shadow_dx + 3, 
                       image.height + top_dy + shadow_dy + 3)

        # draw image
        print '!',
        image.draw(canvas, image.bounds, dest)

        # test alpha-transparency
        #canvas.fillcolor = rgb(0.0, 0.5, 0.0, 0.5)
        #canvas.fill_frame_rect((50, 50, 300, 300))

        # draw selection
        if self.selection is not None:

            # outer darkening
            # disabled for now - need to work out invalidation and 
            # double-buffering
            #canvas.forecolor = rgb(0.0, 0.0, 0.0, 0.5)
            #uleft, utop, uright, ubottom = update_rect
            #sleft, stop, sright, sbottom = self.selection
            #canvas.fill_poly([
            #    (uleft, ubottom),
            #    (uleft, utop),
            #    (uright, utop),
            #    (uright, ubottom),
            #    (sleft, ubottom),
            #    (sleft, sbottom),
            #    (sright, sbottom),
            #    (sright, stop),
            #    (sleft, stop),
            #    (sleft, ubottom),
            #    ])

            # frame
            canvas.pencolor = black
            canvas.frame_rect(self.selection)

        self.become_target()

    def mouse_move(self, event):

        # ignore event when image is not yet drawn
        try: 
            self.image
        except AttributeError:
            return

        self.set_status(mouse=self.pdfpoint(event.position))

        # choose and set cursor for selection changing
        if self.selection is not None:
            left, top, right, bottom = self.selection
            x, y = event.position
            sensivity = 10

            if near((left, top), (x, y), sensivity):      # corners
                self.cursor = sizer_nw_se
                self.changespec = dict(istop=True, isleft=True)
            elif near((right, bottom), (x, y), sensivity):
                self.cursor = sizer_nw_se
                self.changespec = dict(istop=False, isleft=False)
            elif near((right, top), (x, y), sensivity):
                self.cursor = sizer_ne_sw
                self.changespec = dict(istop=True, isleft=False)
            elif near((left, bottom), (x, y), sensivity):
                self.cursor = sizer_ne_sw
                self.changespec = dict(istop=False, isleft=True)
            elif abs(x-left) <= sensivity and top < y < bottom:   # sides
                self.cursor = sizer_w_e
                self.changespec = dict(isleft=True)
            elif abs(x-right) <= sensivity and top < y < bottom:
                self.cursor = sizer_w_e
                self.changespec = dict(isleft=False)
            elif abs(y-top) <= sensivity and left < x < right:
                self.cursor = sizer_n_s
                self.changespec = dict(istop=True)
            elif abs(y-bottom) <= sensivity and left < x < right:
                self.cursor = sizer_n_s
                self.changespec = dict(istop=False)
            elif pt_in_rect((x, y), self.selection):      # inside
                self.cursor = finger
            else:                                                 # elsewhere
                self.cursor = crosshair

    def mouse_down(self, event):
        if self.cursor in (sizer_nw_se, sizer_ne_sw, sizer_w_e, sizer_n_s):
            self.change_selection(**self.changespec)
        elif self.cursor == finger:
            self.move_selection(event.position)
        else:
            self.select(event.position)

    def move_selection(self, (x0, y0)):
        for event in self.track_mouse():
            x, y = event.position
            nsel = offset_rect(self.selection, (x-x0,y-y0))
            x0, y0 = x, y

            self.set_status(mouse=self.pdfpoint((x, y)))

            self.setselection(confine_rect(nsel, self.viewrect))

    def change_selection(self, istop=None, isleft=None):
        for event in self.track_mouse():

            x, y = event.position
            left, top, right, bottom = self.selection

            if isleft is not None:
                if isleft: left = x
                else:      right = x
                if left > right: isleft = not isleft

            if istop is not None:
                if istop: top = y
                else:     bottom = y
                if top > bottom: istop = not istop

            if istop is not None and isleft is not None: # corners
                if (istop and isleft) or (not istop and not isleft):
                    self.cursor = sizer_nw_se
                elif (istop and not isleft) or (not istop and isleft):
                    self.cursor = sizer_ne_sw

            self.set_status(mouse=self.pdfpoint((x, y)))
            self.setselection(norm_rect((left, top, right, bottom)))

    def select(self, (x0, y0)):
        for event in self.track_mouse():
            x, y = event.position
            self.set_status(mouse=self.pdfpoint((x, y)))
            self.setselection(norm_rect((x0, y0, x, y)))

    def setselection(self, rect):
        if self.selection == rect: # nothing changed
            return

        if self.selection is not None:
            self.invalidate_frame(self.selection) # erase previous

        if rect_width(rect) == 0 and rect_height(rect) == 0:    # just a click
            self.selection = None
            self.set_status(selection=None)
            hide(self.crop_button)
        else:                                                   # selection
            rect = clamp_rect(rect, self.viewrect)
            self.set_status(selection=self.pdfcoord(rect))
            self.crop_button.show()
            self.selection = rect
            self.invalidate_frame(rect)

    def invalidate_frame(self, rect):

        # Below is a logic to invalidate just the frame, not the whole rect.
        # This is to fight flicker. A better fix is to use double buffering.
        # If fixed, all of this could be just: self.invalidate_rect(rect)
        
        w, h = rect_size(rect)
        topleft = rect_topleft(rect)
        topright = add_pt(topleft, (w-1, 0))
        botleft = add_pt(topleft, (0, h-1))

        self.invalidate_rect(rect_sized(topleft, (1, h)))
        self.invalidate_rect(rect_sized(topleft, (w, 1)))
        self.invalidate_rect(rect_sized(topright, (1, h)))
        self.invalidate_rect(rect_sized(botleft, (w, 1)))

    # Was needed before "ScrollableView mouse event position wrong" bug fix.
    #def invalidate(self):
    #    # Force refresh to work-around (windows only?) bug:
    #    #   1. scroll view somewhere
    #    #   2. select region and crop
    #    #   3. refresh wouldn't happen right away - need to draw mouse around
    #
    #    ScrollableView.invalidate(self)
    #    self.scroll_offset = (0,0)


def near(p0, p1, radius):
    x0, y0 = p0
    x1, y1 = p1
    return ((x0-x1)**2 + (y0-y1)**2)**0.5 <= radius

def norm_rect(rect):
    x0, y0, x1, y1 = rect

    left = min(x0, x1)
    right = max(x0, x1)
    top = min(y0, y1)
    bottom = max(y0, y1)

    return left, top, right, bottom


class PDFDoc(Document):
    _rerender = {}
    _images = {} # XXX check memory usage

    def read_contents(self, file):
        # file is already opened, but mupdf supports filenames only for now
        print 'reading', file, file.name
        self.pdf = mupdf.PDF(file.name)
        self.numpages = len(self.pdf)

    def write_contents(self, file):
        self.pdf.fastsave(file)

    def pageimage(self, pagenum):
        if pagenum not in self._rerender or self._rerender[pagenum]:
            page = self.pdf[pagenum]

            left, bottom, right, top = page.bounds
            rect = (left, top, right, bottom)

            self._images[pagenum] = rect, page.image_GDI()
            self._rerender[pagenum] = False

        return self._images[pagenum]

    def crop(self, pagenum, rect):
        print 'PDFDoc.crop(%s)' % (rect,)
        self.pdf[pagenum].bounds = rect
        self.pdf.memorysave()
        #print self.pdf.memorycontent()
        self.changed()
        self._rerender[pagenum] = True
        self.notify_views()

PDFEditor().run()
