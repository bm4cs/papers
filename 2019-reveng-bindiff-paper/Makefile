all: clean paper

paper:
	pandoc -s -F pandoc-crossref -F pandoc-citeproc --bibliography=paper.bib \
	--variable papersize=a4paper \
	-s paper.md -o paper.pdf

#TODO: --template option

# How to make a scientific looking PDF from markdown (with bibliography)
# https://gist.github.com/maxogden/97190db73ac19fc6c1d9beee1a6e4fc8


clean:
	rm -f *.pdf *.log

