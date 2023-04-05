#!/usr/bin/perl -w

# RACER brief record tool, version 0.02
# 18 Nov 2019, last revised 5 April 2023
# racer-records.pl
#
# Given a call number and barcode via a webform, create a brief record in Alma

use strict;

use CGI::Carp qw( fatalsToBrowser );
use CGI qw(:standard escapeHTML);
use lib qw(PATH_TO_PERL_LIBRARIES_1 PATH_TO_PERL_LIBRARIES_2);
use HTML::Template;
use HTML::Entities;

my $racer_library = '[RACER_LIBRARY]'
my $racer_location = '[RACER_LOCATION]'

main();
exit (0);


sub main
{
	my $q = new CGI;
	my $user = $ENV{REMOTE_USER};
	my $tmpl;

	print header();

	# Check for authorized user
	unless (($user ne "not logged in") && ($user ne "")) {
		print "<html><body><h1>Authorization refused</h1></body></html>\n";
		exit;
	}
	my $choice = lc($q->param("doit"));
	print "<!-- doit value is " . $choice . "-->\n";

	if ($choice eq "add racer") {
		$tmpl = add_racer_record($q,'add_racer',$user);
	} else {
		$tmpl = ($q->param('username')) ? show_form($q,$user,'','') : show_form($q,$user,'Login successful.','OK');
	}

	print $tmpl->output;
}

sub add_racer_record
{
	my $q = shift;
	my $choice = shift;
	my $user = shift;

	if ($choice eq "add_racer") {
		use strict;
		use LWP::UserAgent;
		use XML::Twig;
		use HTTP::Request;
		use AlmaAPI;

		my $twig = XML::Twig->new( pretty_print => 'indented');
		my $tmpl;

		open (LOGFILE, '>>racerbibs.log') or die $!;
		my $verbose = 1;

		my $apikey = AlmaAPI::api_key('QuickTitle');
		my $baseurl = AlmaAPI::base_url();

		my $racer_number = $q->param ('racer_number');
		unless ($racer_number) {
			$tmpl = show_form($q,$user,'Missing RACER number','ERR');
			return $tmpl;
		}
		my $racer_barcode = $q->param ('racer_barcode');
		unless ($racer_barcode) {
			$tmpl = show_form($q,$user,'Missing barcode number','ERR');
			return $tmpl;
		}

   		# Create RACER bibliographic record
		my $racer_bib = '<bib><suppress_from_publishing>true</suppress_from_publishing><suppress_from_external_search>true</suppress_from_external_search><sync_with_oclc>NONE</sync_with_oclc><title>RACER #' . $racer_number . '</title><record><leader>00260nam a2200109 u 4500</leader><datafield ind1="1" ind2="0" tag="245"><subfield code="a">RACER #' . $racer_number . '</subfield></datafield></record></bib>' . "\n";

		my $url = $baseurl . 'almaws/v1/bibs?validate=false&override_warning=true';

		print LOGFILE "RACER bib creation URL: $url\n" if $verbose;
		print LOGFILE "RACER bib record: $racer_bib\n" if $verbose;

		$twig = make_alma_request($url,$racer_bib,$apikey);
		my $twig_xml_string = $twig->sprint;
		print LOGFILE "XML retrieved from Alma:\n\n$twig_xml_string\n" if ($verbose);
		my $bib = $twig->first_elt( 'bib' );
		my $bib_mms_id = $bib->first_child_text( 'mms_id' );
		print LOGFILE "Bib MMS ID for RACER $racer_number: $bib_mms_id\n";

		# Create RACER holdings record
		my $racer_holding = '<holding><record><leader>00129nx  a22000611n 4500</leader><controlfield tag="008">1011252u    8   4001uueng0000000</controlfield><datafield ind1="0" ind2=" " tag="852"><subfield code="b">' . $racer_library . '</subfield><subfield code="c">' . $racer_location . '</subfield></datafield></record></holding>';

		$url = $baseurl . 'almaws/v1/bibs/' . $bib_mms_id . '/holdings';

		print LOGFILE "RACER holdings creation URL: $url\n" if $verbose;
		print LOGFILE "RACER holdings record: $racer_bib\n" if $verbose;

		$twig = make_alma_request($url,$racer_holding,$apikey);
		my $twig_xml_string = $twig->sprint;
		print LOGFILE "XML retrieved from Alma:\n\n$twig_xml_string\n" if ($verbose);
		my $holding = $twig->first_elt( 'holding' );
		my $holding_mms_id = $holding->first_child_text( 'holding_id' );
		print LOGFILE "Holding MMS ID for RACER $racer_number: $bib_mms_id\n";

		# Create RACER item record
		my $racer_item = '<item link="string"><item_data><barcode>' . $racer_barcode . '</barcode><policy><xml_value>ILL-ITEM</xml_value></policy></item_data></item>';

		$url = $baseurl . 'almaws/v1/bibs/' . $bib_mms_id . '/holdings/' . $holding_mms_id . '/items';

		print LOGFILE "RACER item creation URL: $url\n" if $verbose;
		print LOGFILE "RACER item record: $racer_bib\n" if $verbose;

		$twig = make_alma_request($url,$racer_item,$apikey);
		my $twig_xml_string = $twig->sprint;
		print LOGFILE "XML retrieved from Alma:\n\n$twig_xml_string\n" if ($verbose);
		print LOGFILE "Raw XML retrieved from Alma:\n\n$twig\n" if ($verbose);
		my ($error_xml,$err_list,$error,$err_message);
		$error_xml = $twig->first_elt( 'web_service_result' );
		if ($error_xml) {
			$err_list = $error_xml->first_child('errorList');
		#	$err_message = $error_xml->first_child_text('errorsExist');
			$error = $err_list->first_child('error');
			$err_message = $error->first_child_text( 'errorMessage' );
			print LOGFILE "Problem creating item: $err_message\n";
			$tmpl = show_form($q,$user,'Problem creating item: ' . $err_message,'ERR');
			return $tmpl;
		} else {
			$tmpl = show_form($q,$user,'RACER #' . $racer_number . ' added.','OK');
			return $tmpl;
		}

	}
}

sub show_form
{
	my $q = shift;
	my $user = shift;
	my $message = shift;
    my $message_style = shift;

	my $template = ($message) ? './message.tmpl' : './blank.tmpl';

	my $tmpl = HTML::Template->new (
           filename => $template,
           die_on_bad_params => 0
        );

	if ($message) {
	    $tmpl->param(message => $message );
	    if ($message_style eq 'OK') {
	        $tmpl->param(message_div => 'alert alert-success' );
	        $tmpl->param(message_span => 'glyphicon glyphicon-ok' );
	    } elsif ($message_style eq 'ERR') {
	        $tmpl->param(message_div => 'alert alert-danger' );
	        $tmpl->param(message_span => 'glyphicon glyphicon-exclamation-sign' );
	    }
	}

	$tmpl->param(username => $user );
	return $tmpl;
}

sub make_alma_request {
	my $url = shift;
	my $xml_body = shift;
	my $apikey = shift;

	my $twig = XML::Twig->new( pretty_print => 'indented');
	my $ua = LWP::UserAgent->new( timeout => 10);

	# set custom HTTP request header fields
	my $req = HTTP::Request->new(POST => $url);
	$req->header('accept' => 'application/xml');
	$req->header('Content-Type' => 'application/xml');
	$req->header('authorization' => "apikey $apikey");

	# add POST data to HTTP request body
	$req->content($xml_body);

	my $response = $ua->request($req);
	my $status = log_alma_response($response);

	my $xml_string = $response->content;
	$twig->parse( $xml_string );
	return $twig;
}

sub log_alma_response {
	my $response = shift;
	if ($response->is_success) {
		print LOGFILE 'Response retrieved from Alma:' . $response->status_line . "\n";
	} else {
		print LOGFILE 'ERROR: Error while getting URL: ' . $response->request->uri . "\n";
		print LOGFILE 'ERROR: ' . $response->status_line . "\n\n";
	}
	return (0);
}
