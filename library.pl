=head1 library.pl
This program takes a text document of ISBN numbers and looks up the Dewey
Decimal System number for each ISBN. The script then outputs the ISBN, Title,
and Dewey Decimal Number to an Excel Spreadsheet
=cut

use Excel::Writer::XLSX;
use WWW::Mechanize;

use 5.14.2;

=item loadISBN()
	This function loads ISBN numbers from the specified file
	
	Parameters:
	1. a filehandle from which the ISBN numbers will be read
	
	returns an array of ISBN numbers
=cut
sub loadISBN {
	my $filename = pop(@_);
	
	open my $fh, "<", $filename or die $!;
	
	my @isbn_list;
	while(<$fh>) {
		#say $_;
		chomp;
		push(@isbn_list, $_);
	}
	
	say "Loaded " . $#isbn_list . " ISBNs.";
	return @isbn_list;
}

=item findBook(isbn)
	findBook() searches the web for an ISBN number and returns the books
	ISBN, Title, and Dewey Decimal System number
	
	Parameters:
	1. a single ISBN number to search for
	
	returns an array of the format {ISBN, book title, DDC}
=cut
sub findBook {
	say "Searching for: " . $_[0];
	
	my $isbn = pop(@_);
	my $url_base = 'http://isbndb.com';
	my $mech = WWW::Mechanize->new();
	$mech->get($url_base);
	
	## Testting code to find which form to submit
	############################################
	##my @forms = $mech->forms;
	##for(@forms){
	##	print $_->dump . "\n"; 
	##}
	#############################################


	my $r = $mech->submit_form( form_name => 'searchform', ## The form name
								fields => {kw => $isbn},   ## kw is the name of the box to fill
							);
	
	## Testing code to see how $r->content looks
	############################################
	##print $r->content;
	############################################
	
	my @content = split("\n", $r->content);
	my %line;
	
	
	for(@content) {
		if(m#(<title>)(?<TITLE>.+)(</title>)#){
			$line{TITLE} = $+{TITLE};	
			##say "found $+{TITLE}";	
		}
		if(/(DDC: )\s?(?<DEWEY>\d+\.?\d*)/) { ## Find the Dewey Decimal Number
			$line{DDC} = $+{DEWEY};
			##say "found $+{DEWEY}";		
			last;
		}	
	}
	
	#$line{TITLE} = 'Unknown' if !$line{TITLE}; #ensure we don't leave the value for DDC null
	#$line{DDC} = 0 if !$line{DDC}; #ensure we don't leave the value for DDC null
	if ($line{TITLE} =~ /Search for '\d+' (ISBNdb.com)/) {
		($line{TITLE}, $line{DDC}) = googleIt($isbn);
	} 

	
	return ($isbn, $line{TITLE}, $line{DDC});
}

=item googleIt()
	This function attempts to find a books Title and DDC
	by performing a google search
	
	Parameters:
		1. an ISBN number
		
	This function returns the books TITLE and DDC
=cut
sub googleIt {
	## Declare variables
	my $isbn = pop @_;
	my ($title, $ddc, $url);
	
	
	## Perform a google search and save the results
	my $mech = WWW::Mechanize->new();
	$mech->get('https://www.google.com/#q='.$isbn.'%20Dewey%20Decimal&fp=1');
	my $r = $mech->submit_form( form_name => 'searchform', ## The form name
								fields => {kw => $isbn},   ## kw is the name of the box to fill
							);
	my @content = split("\n", $r->content);
	
	#Search through the results for a Dewey Decimal Code
	for(my $i=0; $i<$#content; $i++) {
		say $content[$i];
				
		if($content[$i] =~ m#Dewey\s+(Decimal\s+((System)?(Code)?)?)#i) { #Find Dewey or Dewey Decimal or Dewey Decimal Sysstem or Dewey Decimal Code
			my @holder = $content[0-$i]; ## Dump the rest of the page below where we found a Dewey code
			@holder = reverse @holder;
			for(@holder){
				if(m#<a href="(?<URL>.*?)"#){ #non-greedy match
					$url = $+{URL};
					last;
				}	
			}						 
			last;
		}	
	}
	
	@content = split("\n", $mech->get($url)->content);
	
	for(@content){
		if(m#(<title>)(?<TITLE>.+)(</title>)#) {
			$title = $+{TITLE};	
		}
		if(m#Dewey\s+(Decimal\s+((System)?(Code)?)?)(?<DEWEY>\d+\.?\d*)#) {
			$ddc = $+{DEWEY};
			last;
		}
	}
	
	$title = 'Unknown' if !$title; #ensure we don't leave the value for DDC null
	$ddc = 0 if !$ddc; #ensure we don't leave the value for DDC null
	
	return $title, $ddc;
}

=item toExcel(f)
	This function, which takes an array as its parameter, takes
	the result of the function and exports it to an excel spreadsheet
		
	Parameters:
	1. an array, of the format: {ISBN, Title, DDC}, which will be printed to an excel row
	2. an Excel::Writer::XLSX workbook (or would a worksheet be better?)
	
	returns nothing
=cut
sub toExcel {
	say "Populating Excel workbook";
	
	my $workbook_name = pop(@_);
	my @cells = @_;
		
	
	my $workbook = Excel::Writer::XLSX->new($workbook_name);
	my $worksheet = $workbook->add_worksheet();
	
	for my $i (0..int($#cells / 3)) {
		for my $j (0..2) {
			$worksheet->write($i, $j, pop @cells);
		}	
	}
	## May implement formatting later for ISBN column
	#my $format = $workbook->add_format();
	$workbook->close()
}

=item comment
my @cells;
my @isbn_list = loadISBN('codes-list.csv');

for(@isbn_list){
	my @details = findBook($_);
	push @cells, @details;
}

toExcel(@cells, 'library.xlsx');
=cut

print googleIt(9780891346685);