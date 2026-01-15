$ENV{'TEXINPUTS'} = './lib//:' . ($ENV{'TEXINPUTS'} // '');

# Place auxiliary files (aux, log, synctex, etc.) in ./temp, but keep PDF in project root
$aux_dir = 'temp';
$emulate_aux_dir = 1;

# Ensure BibTeX operates in the directory that holds the .aux
$bibtex_use = 2;

# Enable SyncTeX and let latexmk pass the flag to the engine
$pdflatex = 'pdflatex -synctex=1 %O %S';

# Ensure the temp directory exists before running engines
BEGIN {
	my $d = 'temp';
	if (!-d $d) {
		mkdir $d or warn "latexmkrc: could not create '$d': $!\n";
	}
}

# After the full build, ensure the SyncTeX file lives in temp (keep PDF in root)
END {
	my $syn = $root_filename . '.synctex.gz';
	my $dst = File::Spec->catfile('temp', $syn);
	if (-e $syn) {
		unlink $dst if -e $dst;
		rename $syn, $dst or warn "latexmkrc: could not move '$syn' to '$dst': $!\n";
	}
}