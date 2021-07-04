all: clean paper

paper:
	pandoc -s -F pandoc-crossref -F pandoc-citeproc --bibliography=paper.bib \
	--variable papersize=a4paper \
	-s paper.md -o paper.pdf
#	--variable classoption=twocolumn \

latex:
	pandoc -s -F pandoc-crossref -F pandoc-citeproc --bibliography=paper.bib \
	--variable papersize=a4paper \
	-s paper.md -t latex -o paper.tex

clean:
	rm -f *.pdf *.log *.tex

