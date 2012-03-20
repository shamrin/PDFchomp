@c:/python26/python -c "import cydoctest, mupdf; cydoctest.testmod(mupdf)"
@cd tests
@c:/python26/python -m doctest mupdf.doctest
@cd ..
