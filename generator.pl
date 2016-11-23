use strict;
use Carp;
use Win32::TieRegistry ( Delimiter=>"/", ArrayValues=>0 );
use Data::Dumper;
use Text::CSV;
no strict 'refs';

my $delim = "#";
 
sub toArray {
        my $literal = shift;
        my $rkey = $Registry->{$literal}
            or  warn "* Can't read the registry key for $literal:\n $^E\n" and return undef;
        $_ = &_iterate ($rkey,$literal);
        @_ = ();
        foreach my $i (keys %$_){
                push @_, "$i".$delim."$_->{$i}";
        }
        return @_;
}

 
sub _iterate { my ($key,$root) = (shift,shift);
        my $info = shift  || {};
        foreach my $entry (  keys(%$key)  ) {
                if ($key->SubKeyNames) {
                        &_iterate( $key->{$entry}, $root.$delim.$entry, $info );
                } else {
                        $info->{$root.$delim.$entry} = $key->{$entry};
                }
        }
        return $info;
}

sub remove_base_hash {
        my $h = shift;
        my $base = shift;
        for my $k (keys %$h) {
                my $j = $k;
                $j =~ s/$base//;
                my $new_key = $j;
                $h->{$new_key} = delete $h->{$k};
        }
        return $h;
}


sub remove_base_array {
  my $a = shift;
  my $base = shift;
  for (@$a) {
      $_ =~ s/$base//;        
  }
  return $a;
}

=method split_array

Transform an array of strings into array of arrays 

String is parsing into array based on delimeter

'Maxtor#Models#Maxtor_Ares' will be [ 'Maxtor', 'Models', 'Maxtor_Ares' ]

=cut


sub split_array {
   my $a = shift;
   for (@$a) {
     $_ = [ split(/$delim/, $_) ];
   }
   return $a;
}

sub filter_array {
   my $a = shift;
   for my $i (0 .. scalar @$a) {
      if ($a->[$i][4] =~ /\/I\d+/) {
        # warn "Deleting...".Dumper $a->[$i][4];
        delete $a->[$i];
      }
      if ($a->[$i][3] ne 'Models/') {   # remove /ClassId or same
        delete $a->[$i];
      }
   }
   @$a = grep defined, @$a;  # remove all undefs from array
   return $a;
}


sub sort_array {
   my $arr = shift;
   # @$arr = sort { lc($a->[1]) cmp lc($b->[1]) } @$arr;  # sort by vendor
   # @$arr = sort { lc($a->[2]) cmp lc($b->[2]) } @$arr;  # sort by utility
   # @$arr = sort { lc($a->[4]) cmp lc($b->[4]) } @$arr;  # sort by family
   @$arr = sort cmpfunc @$arr;
   return $arr;
}

sub cmpfunc {
    return(($a->[1] cmp $b->[1]) or
           ($a->[2] cmp $b->[2]) or
           ($a->[5] cmp $b->[5]));
}

sub pretiffy_array {
	my $a = shift;
	for my $el (@$a) {
		delete $el->[0]; # empty
		delete $el->[3]; # Models/
		delete $el->[4]; # REG_SZ id
		$el->[4] =~ s/\/M//;
		@$el = grep defined, @$el;
	}
	return $a;
}


sub remove_slashes {
	my $a = shift;
	for my $el (@$a) {
		for (@$el) {
			$_ =~ s/^\///;
			$_ =~ s/\/$//;
		}
	}
}

sub add_header {
	my $a = shift;
	unshift @$a, ['Vendor', 'PC-3000 Utility', 'Family'];
	return $a;
}


sub dump_reg {
        my $base_reg_branches = shift;
        for my $r (@$base_reg_branches) {
                my $base2 = 'LMachine/Software/Wow6432Node/ACE Lab/'.$r.'/Utility/';
                my $b = [ toArray ($base2) ];
                remove_base_array($b, $base2);
                split_array($b);
                filter_array($b);
                sort_array($b);
                pretiffy_array($b);
                remove_slashes($b);
                add_header($b);
                warn Dumper $b;
                my $csv = Text::CSV->new({ eol => "\n" });
                open my $fh, ">:encoding(utf8)", "$r.csv" or die "$r.csv: $!";
                $csv->print ($fh, $_) for @$b;
                close $fh or die "$r.csv: $!";
        }
}

dump_reg(['PC3000Express', 'PC3000ExpressSSD']);


