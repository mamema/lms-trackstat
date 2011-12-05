#         TrackStat::Statistics::NotRatedRecent module
#    Copyright (c) 2006 Erland Isaksson (erland_i@hotmail.com)
# 
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


use strict;
use warnings;
                   
package Plugins::TrackStat::Statistics::NotRatedRecent;

use Date::Parse qw(str2time);
use Fcntl ':flock'; # import LOCK_* constants
use File::Spec::Functions qw(:ALL);
use File::Basename;
use XML::Parser;
use DBI qw(:sql_types);
use Class::Struct;
use FindBin qw($Bin);
use POSIX qw(strftime ceil);
use Slim::Utils::Strings qw(string);
use Plugins::TrackStat::Statistics::Base;
use Slim::Utils::Prefs;

my $prefs = preferences("plugin.trackstat");
my $serverPrefs = preferences("server");


if ($] > 5.007) {
	require Encode;
}

my $driver;
my $distinct = '';

sub init {
	$driver = $serverPrefs->get('dbsource');
    $driver =~ s/dbi:(.*?):(.*)$/$1/;
    
	if(UNIVERSAL::can("Slim::Schema","sourceInformation")) {
		my ($source,$username,$password);
		($driver,$source,$username,$password) = Slim::Schema->sourceInformation;
	}

    if($driver eq 'mysql') {
    	$distinct = 'distinct';
    }
}

sub getStatisticItems {
	my %statistics = (
		notratednotrecent => {
			'webfunction' => \&getNotRatedNotRecentTracksWeb,
			'playlistfunction' => \&getNotRatedNotRecentTracks,
			'id' =>  'notratednotrecent',
			'listtype' => 'track',
			'namefunction' => \&getNotRatedNotRecentTracksName,
			'groups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRECENT_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_TRACK_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')]],
			'statisticgroups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_TRACK_GROUP')]],
			'contextfunction' => \&isNotRatedNotRecentTracksValidInContext
		},
		notratednotrecentartists => {
			'webfunction' => \&getNotRatedNotRecentArtistsWeb,
			'playlistfunction' => \&getNotRatedNotRecentArtistTracks,
			'id' =>  'notratednotrecentartists',
			'listtype' => 'artist',
			'namefunction' => \&getNotRatedNotRecentArtistsName,
			'groups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRECENT_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_ARTIST_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')]],
			'statisticgroups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_ARTIST_GROUP')]],
			'contextfunction' => \&isNotRatedNotRecentArtistsValidInContext
		},
		notratednotrecentalbums => {
			'webfunction' => \&getNotRatedNotRecentAlbumsWeb,
			'playlistfunction' => \&getNotRatedNotRecentAlbumTracks,
			'id' =>  'notratednotrecentalbums',
			'listtype' => 'album',
			'namefunction' => \&getNotRatedNotRecentAlbumsName,
			'groups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRECENT_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_ALBUM_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')]],
			'statisticgroups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_ALBUM_GROUP')]],
			'contextfunction' => \&isNotRatedNotRecentAlbumsValidInContext
		}
	);
	if($prefs->get("history_enabled")) {
		$statistics{notratedrecent} = {
			'webfunction' => \&getNotRatedRecentTracksWeb,
			'playlistfunction' => \&getNotRatedRecentTracks,
			'id' =>  'notratedrecent',
			'listtype' => 'track',
			'namefunction' => \&getNotRatedRecentTracksName,
			'groups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_RECENT_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_TRACK_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')]],
			'statisticgroups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_RECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_TRACK_GROUP')]],
			'contextfunction' => \&isNotRatedRecentTracksValidInContext
		};

		$statistics{notratedrecentartists} = {
			'webfunction' => \&getNotRatedRecentArtistsWeb,
			'playlistfunction' => \&getNotRatedRecentArtistTracks,
			'id' =>  'notratedrecentartists',
			'listtype' => 'artist',
			'namefunction' => \&getNotRatedRecentArtistsName,
			'groups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_RECENT_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_ARTIST_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')]],
			'statisticgroups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_RECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_ARTIST_GROUP')]],
			'contextfunction' => \&isNotRatedRecentArtistsValidInContext
		};
				
		$statistics{notratedrecentalbums} = {
			'webfunction' => \&getNotRatedRecentAlbumsWeb,
			'playlistfunction' => \&getNotRatedRecentAlbumTracks,
			'id' =>  'notratedrecentalbums',
			'listtype' => 'album',
			'namefunction' => \&getNotRatedRecentAlbumsName,
			'groups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_RECENT_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_ALBUM_GROUP'),string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')]],
			'statisticgroups' => [[string('PLUGIN_TRACKSTAT_SONGLIST_RECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_GROUP')],[string('PLUGIN_TRACKSTAT_SONGLIST_ALBUM_GROUP')]],
			'contextfunction' => \&isNotRatedRecentAlbumsValidInContext
		};
	}
	return \%statistics;
}

sub getNotRatedRecentTracksName {
	my $params = shift;
	if(defined($params->{'artist'})) {
	    my $artist = Plugins::TrackStat::Storage::objectForId('artist',$params->{'artist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_FORARTIST')." ".Slim::Utils::Unicode::utf8decode($artist->name,'utf8');
	}elsif(defined($params->{'album'})) {
	    my $album = Plugins::TrackStat::Storage::objectForId('album',$params->{'album'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_FORALBUM')." ".Slim::Utils::Unicode::utf8decode($album->title,'utf8');
	}elsif(defined($params->{'genre'})) {
	    my $genre = Plugins::TrackStat::Storage::objectForId('genre',$params->{'genre'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_FORGENRE')." ".Slim::Utils::Unicode::utf8decode($genre->name,'utf8');
	}elsif(defined($params->{'year'})) {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_FORYEAR')." ".$params->{'year'};
	}elsif(defined($params->{'playlist'})) {
	    my $playlist = Plugins::TrackStat::Storage::objectForId('playlist',$params->{'playlist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_FORPLAYLIST')." ".Slim::Utils::Unicode::utf8decode($playlist->title,'utf8');
	}else {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT');
	}
}

sub isNotRatedRecentTracksValidInContext {
	my $params = shift;
	if(defined($params->{'artist'})) {
		return 1;
	}elsif(defined($params->{'album'})) {
		return 1;
	}elsif(defined($params->{'genre'})) {
		return 1;
	}elsif(defined($params->{'year'})) {
		return 1;
	}elsif(defined($params->{'playlist'})) {
		return 1;
	}
	return 0;
}
sub getNotRatedNotRecentTracksName {
	my $params = shift;
	if(defined($params->{'artist'})) {
	    my $artist = Plugins::TrackStat::Storage::objectForId('artist',$params->{'artist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_FORARTIST')." ".Slim::Utils::Unicode::utf8decode($artist->name,'utf8');
	}elsif(defined($params->{'album'})) {
	    my $album = Plugins::TrackStat::Storage::objectForId('album',$params->{'album'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_FORALBUM')." ".Slim::Utils::Unicode::utf8decode($album->title,'utf8');
	}elsif(defined($params->{'genre'})) {
	    my $genre = Plugins::TrackStat::Storage::objectForId('genre',$params->{'genre'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_FORGENRE')." ".Slim::Utils::Unicode::utf8decode($genre->name,'utf8');
	}elsif(defined($params->{'year'})) {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_FORYEAR')." ".$params->{'year'};
	}elsif(defined($params->{'playlist'})) {
	    my $playlist = Plugins::TrackStat::Storage::objectForId('playlist',$params->{'playlist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_FORPLAYLIST')." ".Slim::Utils::Unicode::utf8decode($playlist->title,'utf8');
	}else {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT');
	}
}

sub isNotRatedNotRecentTracksValidInContext {
	my $params = shift;
	if(defined($params->{'artist'})) {
		return 1;
	}elsif(defined($params->{'album'})) {
		return 1;
	}elsif(defined($params->{'genre'})) {
		return 1;
	}elsif(defined($params->{'year'})) {
		return 1;
	}elsif(defined($params->{'playlist'})) {
		return 1;
	}
	return 0;
}
sub getNotRatedRecentTracksWeb {
	my $params = shift;
	my $listLength = shift;
	getNotRatedHistoryTracksWeb($params,$listLength,">",getRecentTime());
    my %currentstatisticlinks = (
    	'album' => 'notratedrecent',
    	'artist' => 'notratedrecentalbums'
    );
    $params->{'currentstatisticitems'} = \%currentstatisticlinks;
}

sub getNotRatedRecentTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = shift;
	return getNotRatedHistoryTracks($client,$listLength,$limit,">",getRecentTime());
}

sub getNotRatedRecentAlbumsName {
	my $params = shift;
	if(defined($params->{'artist'})) {
	    my $artist = Plugins::TrackStat::Storage::objectForId('artist',$params->{'artist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTALBUMS_FORARTIST')." ".Slim::Utils::Unicode::utf8decode($artist->name,'utf8');
	}elsif(defined($params->{'genre'})) {
	    my $genre = Plugins::TrackStat::Storage::objectForId('genre',$params->{'genre'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTALBUMS_FORGENRE')." ".Slim::Utils::Unicode::utf8decode($genre->name,'utf8');
	}elsif(defined($params->{'year'})) {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTALBUMS_FORYEAR')." ".$params->{'year'};
	}elsif(defined($params->{'playlist'})) {
	    my $playlist = Plugins::TrackStat::Storage::objectForId('playlist',$params->{'playlist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTALBUMS_FORPLAYLIST')." ".Slim::Utils::Unicode::utf8decode($playlist->name,'utf8');
	}else {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTALBUMS');
	}
}
sub isNotRatedRecentAlbumsValidInContext {
	my $params = shift;
	if(defined($params->{'artist'})) {
		return 1;
	}elsif(defined($params->{'genre'})) {
		return 1;
	}elsif(defined($params->{'year'})) {
		return 1;
	}elsif(defined($params->{'playlist'})) {
		return 1;
	}
	return 0;
}

sub getNotRatedNotRecentAlbumsName {
	my $params = shift;
	if(defined($params->{'artist'})) {
	    my $artist = Plugins::TrackStat::Storage::objectForId('artist',$params->{'artist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTALBUMS_FORARTIST')." ".Slim::Utils::Unicode::utf8decode($artist->name,'utf8');
	}elsif(defined($params->{'genre'})) {
	    my $genre = Plugins::TrackStat::Storage::objectForId('genre',$params->{'genre'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTALBUMS_FORGENRE')." ".Slim::Utils::Unicode::utf8decode($genre->name,'utf8');
	}elsif(defined($params->{'year'})) {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTALBUMS_FORYEAR')." ".$params->{'year'};
	}elsif(defined($params->{'playlist'})) {
	    my $playlist = Plugins::TrackStat::Storage::objectForId('playlist',$params->{'playlist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTALBUMS_FORPLAYLIST')." ".Slim::Utils::Unicode::utf8decode($playlist->title,'utf8');
	}else {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTALBUMS');
	}
}
sub isNotRatedNotRecentAlbumsValidInContext {
	my $params = shift;
	if(defined($params->{'artist'})) {
		return 1;
	}elsif(defined($params->{'genre'})) {
		return 1;
	}elsif(defined($params->{'year'})) {
		return 1;
	}elsif(defined($params->{'playlist'})) {
		return 1;
	}
	return 0;
}

sub getNotRatedRecentAlbumsWeb {
	my $params = shift;
	my $listLength = shift;
	getNotRatedHistoryAlbumsWeb($params,$listLength,">",getRecentTime());
    my @statisticlinks = ();
    push @statisticlinks, {
    	'id' => 'notratedrecent',
    	'name' => string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_FORALBUM_SHORT')
    };
    $params->{'substatisticitems'} = \@statisticlinks;
    my %currentstatisticlinks = (
    	'album' => 'notratedrecent',
    	'artist' => 'notratedrecentalbums',
    );
    $params->{'currentstatisticitems'} = \%currentstatisticlinks;
}

sub getNotRatedRecentAlbumTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = undef;
	return getNotRatedHistoryAlbumTracks($client,$listLength,$limit,">",getRecentTime());
}

sub getNotRatedRecentArtistsName {
	my $params = shift;
	if(defined($params->{'genre'})) {
	    my $genre = Plugins::TrackStat::Storage::objectForId('genre',$params->{'genre'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTARTISTS_FORGENRE')." ".Slim::Utils::Unicode::utf8decode($genre->name,'utf8');
	}elsif(defined($params->{'year'})) {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTARTISTS_FORYEAR')." ".$params->{'year'};
	}elsif(defined($params->{'playlist'})) {
	    my $playlist = Plugins::TrackStat::Storage::objectForId('playlist',$params->{'playlist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTARTISTS_FORPLAYLIST')." ".Slim::Utils::Unicode::utf8decode($playlist->title,'utf8');
	}else {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTARTISTS');
	}
}
sub isNotRatedRecentArtistsValidInContext {
	my $params = shift;
	if(defined($params->{'genre'})) {
		return 1;
	}elsif(defined($params->{'year'})) {
		return 1;
	}elsif(defined($params->{'playlist'})) {
		return 1;
	}
	return 0;
}

sub getNotRatedNotRecentArtistsName {
	my $params = shift;
	if(defined($params->{'genre'})) {
	    my $genre = Plugins::TrackStat::Storage::objectForId('genre',$params->{'genre'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTARTISTS_FORGENRE')." ".Slim::Utils::Unicode::utf8decode($genre->name,'utf8');
	}elsif(defined($params->{'year'})) {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTARTISTS_FORYEAR')." ".$params->{'year'};
	}elsif(defined($params->{'playlist'})) {
	    my $playlist = Plugins::TrackStat::Storage::objectForId('playlist',$params->{'playlist'});
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTARTISTS_FORPLAYLIST')." ".Slim::Utils::Unicode::utf8decode($playlist->title,'utf8');
	}else {
		return string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTARTISTS');
	}
}
sub isNotRatedNotRecentArtistsValidInContext {
	my $params = shift;
	if(defined($params->{'genre'})) {
		return 1;
	}elsif(defined($params->{'year'})) {
		return 1;
	}elsif(defined($params->{'playlist'})) {
		return 1;
	}
	return 0;
}

sub getNotRatedRecentArtistsWeb {
	my $params = shift;
	my $listLength = shift;
	getNotRatedHistoryArtistsWeb($params,$listLength,">",getRecentTime());
    my @statisticlinks = ();
    push @statisticlinks, {
    	'id' => 'notratedrecent',
    	'name' => string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENT_FORARTIST_SHORT')
    };
    push @statisticlinks, {
    	'id' => 'notratedrecentalbums',
    	'name' => string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDRECENTALBUMS_FORARTIST_SHORT')
    };
    $params->{'substatisticitems'} = \@statisticlinks;
    my %currentstatisticlinks = (
    	'artist' => 'notratedrecentalbums'
    );
    $params->{'currentstatisticitems'} = \%currentstatisticlinks;
}

sub getNotRatedRecentArtistTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = Plugins::TrackStat::Statistics::Base::getNumberOfTypeTracks();
	return getNotRatedHistoryArtistTracks($client,$listLength,$limit,">",getRecentTime());
}

sub getNotRatedNotRecentTracksWeb {
	my $params = shift;
	my $listLength = shift;
	getNotRatedHistoryTracksWeb($params,$listLength,"<",getRecentTime());
    my %currentstatisticlinks = (
    	'album' => 'notratednotrecent',
    	'artist' => 'notratednotrecentalbums'
    );
    $params->{'currentstatisticitems'} = \%currentstatisticlinks;
}

sub getNotRatedNotRecentTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = shift;
	return getNotRatedHistoryTracks($client,$listLength,$limit,"<",getRecentTime());
}

sub getNotRatedNotRecentAlbumsWeb {
	my $params = shift;
	my $listLength = shift;
	getNotRatedHistoryAlbumsWeb($params,$listLength,"<",getRecentTime());
    my @statisticlinks = ();
    push @statisticlinks, {
    	'id' => 'notratednotrecent',
    	'name' => string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_FORALBUM_SHORT')
    };
    $params->{'substatisticitems'} = \@statisticlinks;
    my %currentstatisticlinks = (
    	'album' => 'notratednotrecent',
    	'artist' => 'notratednotrecentalbums',
    );
    $params->{'currentstatisticitems'} = \%currentstatisticlinks;
}

sub getNotRatedNotRecentAlbumTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = undef;
	return getNotRatedHistoryAlbumTracks($client,$listLength,$limit,"<",getRecentTime());
}

sub getNotRatedNotRecentArtistsWeb {
	my $params = shift;
	my $listLength = shift;
	getNotRatedHistoryArtistsWeb($params,$listLength,"<",getRecentTime());
    my @statisticlinks = ();
    push @statisticlinks, {
    	'id' => 'notratednotrecent',
    	'name' => string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENT_FORARTIST_SHORT')
    };
    push @statisticlinks, {
    	'id' => 'notratednotrecentalbums',
    	'name' => string('PLUGIN_TRACKSTAT_SONGLIST_NOTRATEDNOTRECENTALBUMS_FORARTIST_SHORT')
    };
    $params->{'substatisticitems'} = \@statisticlinks;
    my %currentstatisticlinks = (
    	'artist' => 'notratednotrecentalbums'
    );
    $params->{'currentstatisticitems'} = \%currentstatisticlinks;
}

sub getNotRatedNotRecentArtistTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = Plugins::TrackStat::Statistics::Base::getNumberOfTypeTracks();
	return getNotRatedHistoryArtistTracks($client,$listLength,$limit,"<",getRecentTime());
}

sub getNotRatedHistoryTracksWeb {
	my $params = shift;
	my $listLength = shift;
	my $beforeAfter = shift;
	my $beforeAfterTime = shift;
	my $orderBy = Plugins::TrackStat::Statistics::Base::getRandomString();
	my $sql;
	if(defined($params->{'artist'})) {
		my $artist = $params->{'artist'};
	    $sql = "select tracks.id,count(track_history.url) as recentplayCount,0 as added,max(track_history.played) as lastPlayed,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks,track_history,contributor_track,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.id=contributor_track.track and contributor_track.contributor=$artist and contributor_track.role in (1,4,5,6) and tracks.audio=1 and played$beforeAfter$beforeAfterTime and (track_statistics.rating is null or track_statistics.rating=0) group by track_history.url order by recentplayCount desc,maxrating desc,$orderBy limit $listLength;";
	    if($beforeAfter eq "<") {
		    $sql = "select tracks.id,track_statistics.playCount,track_statistics.added,track_statistics.lastPlayed,(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks join contributor_track on tracks.id=contributor_track.track and contributor_track.contributor=$artist and contributor_track.role in (1,4,5,6) left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 where tracks.audio=1 and (track_statistics.lastPlayed is null or track_statistics.lastPlayed<$beforeAfterTime) and (track_statistics.rating is null or track_statistics.rating=0) group by tracks.id order by track_statistics.playCount desc,$orderBy limit $listLength;"
	    }
	    $params->{'statisticparameters'} = "&artist=$artist";
	}elsif(defined($params->{'album'})) {
		my $album = $params->{'album'};
	    $sql = "select tracks.id,count(track_history.url) as recentplayCount,0 as added,max(track_history.played) as lastPlayed,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks,track_history,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.audio=1 and tracks.album=$album and played$beforeAfter$beforeAfterTime and (track_statistics.rating is null or track_statistics.rating=0) group by track_history.url order by recentplayCount desc,maxrating desc,$orderBy;";
	    if($beforeAfter eq "<") {
		    $sql = "select tracks.id,track_statistics.playCount,track_statistics.added,track_statistics.lastPlayed,(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 where tracks.audio=1 and tracks.album=$album and (track_statistics.lastPlayed is null or track_statistics.lastPlayed<$beforeAfterTime) and (track_statistics.rating is null or track_statistics.rating=0) order by track_statistics.playCount desc,$orderBy;"
	    }
	    $params->{'statisticparameters'} = "&album=$album";
	}elsif(defined($params->{'genre'})) {
		my $genre = $params->{'genre'};
	    $sql = "select tracks.id,count(track_history.url) as recentplayCount,0 as added,max(track_history.played) as lastPlayed,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks,track_history,genre_track,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.id=genre_track.track and genre_track.genre=$genre and tracks.audio=1 and played$beforeAfter$beforeAfterTime and (track_statistics.rating is null or track_statistics.rating=0) group by track_history.url order by recentplayCount desc,maxrating desc,$orderBy limit $listLength;";
	    if($beforeAfter eq "<") {
		    $sql = "select tracks.id,track_statistics.playCount,track_statistics.added,track_statistics.lastPlayed,(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks join genre_track on tracks.id=genre_track.track and genre_track.genre=$genre left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 where tracks.audio=1 and (track_statistics.lastPlayed is null or track_statistics.lastPlayed<$beforeAfterTime) and (track_statistics.rating is null or track_statistics.rating=0) order by track_statistics.playCount desc,$orderBy limit $listLength;"
	    }
	    $params->{'statisticparameters'} = "&genre=$genre";
	}elsif(defined($params->{'year'})) {
		my $year = $params->{'year'};
	    $sql = "select tracks.id,count(track_history.url) as recentplayCount,0 as added,max(track_history.played) as lastPlayed,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks,track_history,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.audio=1 and tracks.year=$year and played$beforeAfter$beforeAfterTime and (track_statistics.rating is null or track_statistics.rating=0) group by track_history.url order by recentplayCount desc,maxrating desc,$orderBy limit $listLength;";
	    if($beforeAfter eq "<") {
		    $sql = "select tracks.id,track_statistics.playCount,track_statistics.added,track_statistics.lastPlayed,(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 where tracks.audio=1 and tracks.year=$year and (track_statistics.lastPlayed is null or track_statistics.lastPlayed<$beforeAfterTime) and (track_statistics.rating is null or track_statistics.rating=0) order by track_statistics.playCount desc,$orderBy limit $listLength;"
	    }
	    $params->{'statisticparameters'} = "&year=$year";
	}elsif(defined($params->{'playlist'})) {
		my $playlist = $params->{'playlist'};
	    $sql = "select tracks.id,count(track_history.url) as recentplayCount,0 as added,max(track_history.played) as lastPlayed,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks,track_history,playlist_track,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.url=playlist_track.track and playlist_track.playlist=$playlist and tracks.audio=1 and played$beforeAfter$beforeAfterTime and (track_statistics.rating is null or track_statistics.rating=0) group by track_history.url order by recentplayCount desc,maxrating desc,$orderBy limit $listLength;";
	    if($beforeAfter eq "<") {
		    $sql = "select tracks.id,track_statistics.playCount,track_statistics.added,track_statistics.lastPlayed,(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks join playlist_track on tracks.url=playlist_track.track and playlist_track.playlist=$playlist left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 where tracks.audio=1 and (track_statistics.lastPlayed is null or track_statistics.lastPlayed<$beforeAfterTime) and (track_statistics.rating is null or track_statistics.rating=0) order by track_statistics.playCount desc,$orderBy limit $listLength;"
	    }
	    $params->{'statisticparameters'} = "&playlist=$playlist";
	}else {
	    $sql = "select tracks.id,count(track_history.url) as recentplayCount,0 as added,max(track_history.played) as lastPlayed,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks,track_history,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.audio=1 and played$beforeAfter$beforeAfterTime and (track_statistics.rating is null or track_statistics.rating=0) group by track_history.url order by recentplayCount desc,maxrating desc,$orderBy limit $listLength;";
	    if($beforeAfter eq "<") {
		    $sql = "select tracks.id,track_statistics.playCount,track_statistics.added,track_statistics.lastPlayed,(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 where tracks.audio=1 and (track_statistics.lastPlayed is null or track_statistics.lastPlayed<$beforeAfterTime) and (track_statistics.rating is null or track_statistics.rating=0) order by track_statistics.playCount desc,$orderBy limit $listLength;"
	    }
	}
    Plugins::TrackStat::Statistics::Base::getTracksWeb($sql,$params);
}

sub getNotRatedHistoryTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = shift;
	my $beforeAfter = shift;
	my $beforeAfterTime = shift;
	my $orderBy = Plugins::TrackStat::Statistics::Base::getRandomString();
	my $sql;
	if($prefs->get("dynamicplaylist_norepeat")) {
		my $clientid = $client->id;
		$sql = "select tracks.id,count(track_history.url) as recentPlayCount,0 as added,max(track_history.played) as lastPlayed,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks join track_history on tracks.urlmd5=track_history.urlmd5 join track_statistics on tracks.urlmd5=track_statistics.urlmd5 left join dynamicplaylist_history on tracks.id=dynamicplaylist_history.id and dynamicplaylist_history.client='$clientid' where tracks.audio=1 and dynamicplaylist_history.id is null and played$beforeAfter$beforeAfterTime and (track_statistics.rating is null or track_statistics.rating=0) group by track_history.url order by recentPlayCount desc,maxrating desc,$orderBy limit $listLength;";
		if($beforeAfter eq "<") {
			$sql = "select tracks.id,(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 left join dynamicplaylist_history on tracks.id=dynamicplaylist_history.id and dynamicplaylist_history.client='$clientid' where tracks.audio=1 and dynamicplaylist_history.id is null and (track_statistics.lastPlayed is null or track_statistics.lastPlayed<$beforeAfterTime) and (track_statistics.rating is null or track_statistics.rating=0) order by track_statistics.playCount desc,$orderBy limit $listLength;";
		}
	}else {
		$sql = "select tracks.id,count(track_history.url) as recentPlayCount,0 as added,max(track_history.played) as lastPlayed,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks,track_history,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.audio=1 and played$beforeAfter$beforeAfterTime and (track_statistics.rating is null or track_statistics.rating=0) group by track_history.url order by recentPlayCount desc,maxrating desc,$orderBy limit $listLength;";
		if($beforeAfter eq "<") {
			$sql = "select tracks.id,(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 where tracks.audio=1 and (track_statistics.lastPlayed is null or track_statistics.lastPlayed<$beforeAfterTime) and (track_statistics.rating is null or track_statistics.rating=0) order by track_statistics.playCount desc,$orderBy limit $listLength;";
		}
	}
    return Plugins::TrackStat::Statistics::Base::getTracks($sql,$limit);
}

sub getNotRatedHistoryAlbumsWeb {
	my $params = shift;
	my $listLength = shift;
	my $beforeAfter = shift;
	my $beforeAfterTime = shift;
	my $orderBy = Plugins::TrackStat::Statistics::Base::getRandomString();
	my $sql;
	if(defined($params->{'artist'})) {
		my $artist = $params->{'artist'};
	    $sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url)/count($distinct track_history.url) as avgcount,max(track_history.played) as lastplayed, 0 as maxadded  from tracks,track_history, albums,contributor_track,track_statistics where tracks.urlmd5=track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.album=albums.id and tracks.id=contributor_track.track and contributor_track.contributor=$artist and contributor_track.role in (1,4,5,6) and played$beforeAfter$beforeAfterTime group by tracks.album having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,avg(ifnull(track_statistics.playCount,0)) as avgcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded  from tracks join contributor_track on tracks.id=contributor_track.track and contributor_track.contributor=$artist and contributor_track.role in (1,4,5,6) left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join albums on tracks.album=albums.id group by tracks.album having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    }
	    $params->{'statisticparameters'} = "&artist=$artist";
	}elsif(defined($params->{'genre'})) {
		my $genre = $params->{'genre'};
	    $sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url)/count($distinct track_history.url) as avgcount,max(track_history.played) as lastplayed, 0 as maxadded  from tracks,track_history, albums,genre_track,track_statistics where tracks.urlmd5=track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.album=albums.id and tracks.id=genre_track.track and genre_track.genre=$genre and played$beforeAfter$beforeAfterTime group by tracks.album having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,avg(ifnull(track_statistics.playCount,0)) as avgcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded  from tracks join genre_track on tracks.id=genre_track.track and genre_track.genre=$genre left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join albums on tracks.album=albums.id group by tracks.album having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    }
	    $params->{'statisticparameters'} = "&genre=$genre";
	}elsif(defined($params->{'year'})) {
		my $year = $params->{'year'};
	    $sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url)/count($distinct track_history.url) as avgcount,max(track_history.played) as lastplayed, 0 as maxadded  from tracks,track_history, albums,track_statistics where tracks.urlmd5=track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.album=albums.id and tracks.year=$year and played$beforeAfter$beforeAfterTime group by tracks.album having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,avg(ifnull(track_statistics.playCount,0)) as avgcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded  from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join albums on tracks.album=albums.id where tracks.year=$year group by tracks.album having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    }
	    $params->{'statisticparameters'} = "&year=$year";
	}elsif(defined($params->{'playlist'})) {
		my $playlist = $params->{'playlist'};
	    $sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url)/count($distinct track_history.url) as avgcount,max(track_history.played) as lastplayed, 0 as maxadded  from tracks,track_history, albums,playlist_track,track_statistics where tracks.urlmd5=track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.album=albums.id and tracks.url=playlist_track.track and playlist_track.playlist=$playlist and played$beforeAfter$beforeAfterTime group by tracks.album having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,avg(ifnull(track_statistics.playCount,0)) as avgcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded  from tracks join playlist_track on tracks.url=playlist_track.track and playlist_track.playlist=$playlist left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join albums on tracks.album=albums.id group by tracks.album having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    }
	    $params->{'statisticparameters'} = "&playlist=$playlist";
	}else {
	    $sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url)/count($distinct track_history.url) as avgcount,max(track_history.played) as lastplayed, 0 as maxadded  from tracks,track_history, albums,track_statistics where tracks.urlmd5=track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.album=albums.id and played$beforeAfter$beforeAfterTime group by tracks.album having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,avg(ifnull(track_statistics.playCount,0)) as avgcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded  from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join albums on tracks.album=albums.id group by tracks.album having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
	    }
	}
    Plugins::TrackStat::Statistics::Base::getAlbumsWeb($sql,$params);
}

sub getNotRatedHistoryAlbumTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = shift;
	my $beforeAfter = shift;
	my $beforeAfterTime = shift;
	my $orderBy = Plugins::TrackStat::Statistics::Base::getRandomString();
	my $sql;
	if($prefs->get("dynamicplaylist_norepeat")) {
		my $clientid = $client->id;
		$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url)/count($distinct track_history.url) as avgcount,max(track_history.played) as lastplayed, 0 as maxadded  from tracks join track_history on tracks.urlmd5=track_history.urlmd5 join albums on tracks.album=albums.id join track_statistics on tracks.urlmd5=track_statistics.urlmd5 left join dynamicplaylist_history on tracks.id=dynamicplaylist_history.id and dynamicplaylist_history.client='$clientid' where dynamicplaylist_history.id is null and played$beforeAfter$beforeAfterTime group by tracks.album having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
		if($beforeAfter eq "<") {
			$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,avg(ifnull(track_statistics.playCount,0)) as avgcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded  from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join albums on tracks.album=albums.id left join dynamicplaylist_history on tracks.id=dynamicplaylist_history.id and dynamicplaylist_history.client='$clientid' where dynamicplaylist_history.id is null group by tracks.album having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
		}
	}else {
		$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url)/count($distinct track_history.url) as avgcount,max(track_history.played) as lastplayed, 0 as maxadded  from tracks,track_history, albums,track_statistics where tracks.urlmd5=track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.album=albums.id and played$beforeAfter$beforeAfterTime group by tracks.album having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
		if($beforeAfter eq "<") {
			$sql = "select albums.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,avg(ifnull(track_statistics.playCount,0)) as avgcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded  from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join albums on tracks.album=albums.id group by tracks.album having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by avgcount desc,maxrating desc,$orderBy limit $listLength";
		}
	}
    return Plugins::TrackStat::Statistics::Base::getAlbumTracks($client,$sql,$limit);
}

sub getNotRatedHistoryArtistsWeb {
	my $params = shift;
	my $listLength = shift;
	my $beforeAfter = shift;
	my $beforeAfterTime = shift;
	my $orderBy = Plugins::TrackStat::Statistics::Base::getRandomString();
	my $sql;
	if(defined($params->{'genre'})) {
		my $genre = $params->{'genre'};
	    $sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url) as sumcount,max(track_history.played) as lastplayed, 0 as maxadded from tracks,track_history,contributor_track,contributors,genre_track,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) and contributors.id = contributor_track.contributor and tracks.id=genre_track.track and genre_track.genre=$genre and played$beforeAfter$beforeAfterTime group by contributors.id having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,sum(ifnull(track_statistics.playCount,0)) as sumcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded from tracks join genre_track on tracks.id=genre_track.track and genre_track.genre=$genre left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join contributor_track on tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) join contributors on contributors.id = contributor_track.contributor group by contributors.id having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";    
		}
	    $params->{'statisticparameters'} = "&genre=$genre";
	}elsif(defined($params->{'year'})) {
		my $year = $params->{'year'};
	    $sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url) as sumcount,max(track_history.played) as lastplayed, 0 as maxadded from tracks,track_history,contributor_track,contributors,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) and contributors.id = contributor_track.contributor and tracks.year=$year and played$beforeAfter$beforeAfterTime group by contributors.id having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,sum(ifnull(track_statistics.playCount,0)) as sumcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join contributor_track on tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) join contributors on contributors.id = contributor_track.contributor where tracks.year=$year group by contributors.id having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";    
		}
	    $params->{'statisticparameters'} = "&year=$year";
	}elsif(defined($params->{'playlist'})) {
		my $playlist = $params->{'playlist'};
	    $sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url) as sumcount,max(track_history.played) as lastplayed, 0 as maxadded from tracks,track_history,contributor_track,contributors,playlist_track,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) and contributors.id = contributor_track.contributor and tracks.url=playlist_track.track and playlist_track.playlist=$playlist and played$beforeAfter$beforeAfterTime group by contributors.id having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,sum(ifnull(track_statistics.playCount,0)) as sumcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded from tracks join playlist_track on tracks.url=playlist_track.track and playlist_track.playlist=$playlist left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join contributor_track on tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) join contributors on contributors.id = contributor_track.contributor group by contributors.id having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";    
		}
	    $params->{'statisticparameters'} = "&playlist=$playlist";
	}else {
	    $sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url) as sumcount,max(track_history.played) as lastplayed, 0 as maxadded from tracks,track_history,contributor_track,contributors,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) and contributors.id = contributor_track.contributor and played$beforeAfter$beforeAfterTime group by contributors.id having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";
	    if($beforeAfter eq "<") {
			$sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,sum(ifnull(track_statistics.playCount,0)) as sumcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join contributor_track on tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) join contributors on contributors.id = contributor_track.contributor group by contributors.id having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";    
		}
	}
    Plugins::TrackStat::Statistics::Base::getArtistsWeb($sql,$params);
}

sub getNotRatedHistoryArtistTracks {
	my $client = shift;
	my $listLength = shift;
	my $limit = shift;
	my $beforeAfter = shift;
	my $beforeAfterTime = shift;
	my $orderBy = Plugins::TrackStat::Statistics::Base::getRandomString();
	my $sql;
	if($prefs->get("dynamicplaylist_norepeat")) {
		my $clientid = $client->id;
		$sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url) as sumcount,max(track_history.played) as lastplayed, 0 as maxadded from tracks join track_history on tracks.urlmd5=track_history.urlmd5 join contributor_track on tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) join contributors on contributor_track.contributor=contributors.id join track_statistics on tracks.urlmd5=track_statistics.urlmd5 left join dynamicplaylist_history on tracks.id=dynamicplaylist_history.id and dynamicplaylist_history.client='$clientid' where dynamicplaylist_history.id is null and played$beforeAfter$beforeAfterTime group by contributors.id having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";
		if($beforeAfter eq "<") {
			$sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,sum(ifnull(track_statistics.playCount,0)) as sumcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join contributor_track on tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) join contributors on contributors.id = contributor_track.contributor left join dynamicplaylist_history on tracks.id=dynamicplaylist_history.id and dynamicplaylist_history.client='$clientid' where dynamicplaylist_history.id is null group by contributors.id having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";    
		}
	}else {
		$sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,count(track_history.url) as sumcount,max(track_history.played) as lastplayed, 0 as maxadded from tracks,track_history,contributor_track,contributors,track_statistics where tracks.urlmd5 = track_history.urlmd5 and tracks.urlmd5=track_statistics.urlmd5 and tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) and contributors.id = contributor_track.contributor and played$beforeAfter$beforeAfterTime group by contributors.id having max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";
		if($beforeAfter eq "<") {
			$sql = "select contributors.id,max(case when track_statistics.rating is null then 0 else track_statistics.rating end) as maxrating,sum(ifnull(track_statistics.playCount,0)) as sumcount,max(track_statistics.lastPlayed) as lastplayed, max(track_statistics.added) as maxadded from tracks left join track_statistics on tracks.urlmd5 = track_statistics.urlmd5 join contributor_track on tracks.id=contributor_track.track and contributor_track.role in (1,4,5,6) join contributors on contributors.id = contributor_track.contributor group by contributors.id having (max(track_statistics.lastPlayed) is null or max(track_statistics.lastPlayed)<$beforeAfterTime) and max(case when track_statistics.rating is null then 0 else track_statistics.rating end)=0 order by sumcount desc,maxrating desc,$orderBy limit $listLength";    
		}
	}
    return Plugins::TrackStat::Statistics::Base::getArtistTracks($client,$sql,$limit);
}


sub getRecentTime() {
	my $days = $prefs->get("recent_number_of_days");
	if(!defined($days)) {
		$days = 30;
	}
	return time() - 24*3600*$days;
}


1;

__END__
