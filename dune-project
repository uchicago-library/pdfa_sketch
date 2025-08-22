(lang dune 3.13)
(name pdfaer)
(generate_opam_files true)
(package
 (name pdfaer)
 (description "This simple project is meant to provide a library and executable which converts PDFs
into PDF/A-compliant files for the University of Chicago's DLDC attachment converter project.
This project is essentially an extension of John Whitington's Camlpdf library, while also
meshing it with Ezxmlm, a version of Xmlm supposedly easier to understand and work with.
The program runs as follows: 1) Look for non-compliancy - which parts of the PDF are non-compliant
with the PDFA standards? 2) For whichever aspects of the file are non-compliant, then are they
either implemented in the PDF but wrong, or are they simply absent from the file altogether? In 
the latter case, create the missing piece, insert the relevant objects, and insert/modify references to them from
depending objects. In the former case, then parse the existing object, look for what the error is, modify it, and
reinsert the modified object altogether. Do this for all pertinent problems, and return the edited file.")
 (synopsis "Simple API and executable for converting pdf files into pdfa-compliant files.")
 (maintainers "fongo@uchicago.edu")
 (authors "fongo@uchicago.edu") 
 (homepage https://your.website.here)
 (bug_reports https://your.documentation.here)
 (depends
  (ocaml (>= 4.14.0))
   dune
   utop
   camlpdf
   ezxmlm
   prelude
   xmlm)
 (source (github your-username/your-repo)))

; Local Variables:
; mode: dune
; End:
