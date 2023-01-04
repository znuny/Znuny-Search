# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Article::ArticleDataMIMEAttachment;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Plugins::ES::Ingest',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    return if $SearchObject->{Fallback};

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Data Event Config)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $IngestPluginObject = $Kernel::OM->Get('Kernel::System::Search::Plugins::ES::Ingest');

    if ( $Param{Event} eq 'ArticleCreate' ) {
        my $Result = $SearchObject->ObjectIndexAdd(
            Index       => 'ArticleDataMIMEAttachment',
            QueryParams => {
                ArticleID => $Param{Data}->{ArticleID}
            }
        );
    }
    elsif ( $Param{Event} eq 'ArticleUpdate' ) {
        my $Result = $SearchObject->ObjectIndexSet(
            Index       => 'ArticleDataMIMEAttachment',
            QueryParams => {
                ArticleID => $Param{Data}->{ArticleID}
            }
        );
    }

    return 1;
}

1;
