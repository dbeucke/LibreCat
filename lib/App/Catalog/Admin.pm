package App::Catalog::Admin;

use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;
    
get '/myPUB' => sub {
	forward '/myPUB/86212';
};
	
get '/myPUB/add' => sub {
	template 'edit_researchData.tmpl', {recordOId => "123456789"};#, file => [{fileOId => 1, fileName => "file", accessLevel => "admin", dateLastUploaded => "2014-01-10", isUploadedBy => {login => "kohorst"}}]};
};
	
get qr{/myPUB/(\d{1,})/*} => sub {
	my ($id) = splat;
	my $personInfo = h->getPerson($id);
	my $sbcatId = $personInfo->{sbcatId};
		
	my $p = {
		q => "person=$id AND hide<>$id",
		facets => "",
		limit => h->config->{store}->{maximum_page_size}
	};
	my $hits = h->search_publication($p);
		
	$hits->{sbcatId} = $sbcatId if $sbcatId;
	$hits->{bisId} = $id;
	my $personStyle;
	my $personSort;
	if($personInfo->{stylePreference} and $personInfo->{stylePreference} =~ /(\w{1,})\.(\w{1,})/){
		$personStyle = $1;
		$personSort = $2;
	}
	$hits->{style} = $personStyle || "pub";
	template 'admin.tt', $hits;
};

get '/myPUB/update' => sub {
	template 'admin_update';
};

get '/myPUB/accounts' => sub {
	template 'accounts'
};

get '/myPUB/curate' => sub {
	template 'curate';
};
	
get '/myPUB/search_researcher' => sub {
	my $q = params->{'ftext'};
	my $hits = h->search_researcher({q => $q});
		
	my $jsonstring = "[";
	foreach (@{$hits->{hits}}){
		my $pevzId = $_->{_id};
		my $sbcatId = $_->{sbcatId};
		my $firstName = $_->{givenName};
		$firstName =~ s/"/\\"/g;
		my $lastName = $_->{surname};
		$lastName =~ s/"/\\"/g;
		my $title = $_->{bis_personTitle} || "";
		$jsonstring .= "{pevzId:\"" . $pevzId . "\"";
		$jsonstring .= ", sbcatId:\"" . $sbcatId . "\"";
		$jsonstring .= ", firstName:\"" . $firstName . "\"";
		$jsonstring .= ", lastName:\"" . $lastName . "\"";
		$jsonstring .= ", title:\"" . $title ."\"";
		$jsonstring .= "},";
	}
	$jsonstring =~ s/,$//g;
	$jsonstring .= "]";
	return $jsonstring;
};

get '/myPUB/autocomplete_hierarchy' => sub {
	my $q = params->{'term'} || "";
	my $fmt = params->{fmt} || "autocomplete";
	my $type = params->{type} || "department";
	$q = "name=" . $q . "*" if ($q ne "" and $type ne "researchgroup");
	my $hits;
	
	if($type eq "department"){
		$hits = h->search_department({q => $q, limit => 1000, sort => "name,,0"});
	}
	elsif($type eq "project"){
		$hits = h->search_project({q => $q, limit => 1000});
	}
	elsif($type eq "researchgroup"){
		$hits = h->search_researchgroup({q => $q});
	}
	my $jsonhash = ();
	my $sorted;
	my $fullsort;
	
	#to_dumper($hits);
	
	if($fmt eq "autocomplete"){
		foreach (@{$hits->{hits}}){
			my $label = "";
			$label = $_->{name};
			
			if($_->{parent}){
				$label .= " (";
				if($_->{parent_of_parent}){
					$label .= $_->{parent_of_parent}->{name} . " | ";
				}
				$label .=  $_->{parent}->{name} . ")";
			}
			
			$label =~ s/"/\\"/g;
			push @$jsonhash, {id => $_->{oId}, label => $label};
		}
	}
	else{
		foreach (@{$hits->{hits}}){
			push @$jsonhash, {id => $_->{_id}, label => $_->{name}};
		}
	}
	
	my $json = to_json($jsonhash);
	return $json;

};

1;
