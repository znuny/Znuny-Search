# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search;

use Search::Elasticsearch;
use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Object'
);

=head1 NAME

Kernel::System::Search - TO-DO

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE


=head2 new()

TO-DO

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{ElasticSearch}->{Enabled} = 1;    # MOCK-UP

    # Check if ElasticSearch feature is enabled.
    if ( !$Self->{ElasticSearch}->{Enabled} ) {
        $Self->{ElasticSearch}->{Error} = 1;
    }

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $Self->{Config}->{ActiveEngine} = 'ES';    # MOCK-UP

    # Check if there is choosen active engine of the search.
    if ( !$Self->{Config}->{ActiveEngine} ) {
        $Self->{ElasticSearch}->{Error} = 1;
        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing Search Engine.",
        );
    }

    # If there were no errors before, try connecting.
    $Self->Connect() if !$Self->{ElasticSearch}->{Error};

    return $Self;
}

=head2 Search()

TO-DO

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # If there was an critical error, fallback all of the objects with given search parameters.
    if ( $Self->{ElasticSearch}->{Error} ) {
        my $Response = $Self->Fallback(%Param);
        return $Response;
    }

    NEEDED:
    for my $Needed (qw(Objects SearchParams)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $StructureMapping = {
        "Mapping" => "Kernel::System::Search::Mapping::$Self->{Config}->{ActiveEngine}",
        "Engine"  => "Kernel::System::Search::Engine::$Self->{Config}->{ActiveEngine}",
    };

    my $Result = $SearchObject->QueryPrepare(
        %Param,
        Engine => $Self->{Config}->{ActiveEngine}
    );

    if ( $Result->{Error} ) {
        $Result->{Fallback} = $Self->Fallback(%Param);
    }

    return $Result if !$Result->{Fallback}->{Continue};

    my @Queries = $Result->{Queries} || ();

    my %SearchModules;
    for my $SearchStructureItem (qw ( Mapping Engine )) {
        $SearchModules{$SearchStructureItem} = $Kernel::OM->Get( $StructureMapping->{$SearchStructureItem} );
    }

    my $QueriesToExecute = $Queries[0];

    my @Result;
    for my $Query ( @{$QueriesToExecute} ) {

        my $ResultQuery = $SearchModules{Engine}->QueryExecute(
            Query     => $Query,
            Index     => 'ticket',
            QueryType => 'search'
        );

        push @Result, $ResultQuery;
    }

    # my $Response = {};

    # # TODO: Standarization of specific object response after claryfication of response from query execute.

    return \@Result;

}

=head2 Connect()

TO-DO

=cut

sub Connect {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    my $Connect;

    # try to receive information about cluster after connection.

    # Connection process...

    $Self->{ConnectObject} = Search::Elasticsearch->new(
        nodes => [
            '172.17.0.1:9200',    # MOCK-UP
        ]
    );

    # *Successfully*
    $Connect = 1;                 # MOCK-UP

    eval {
        $Self->{ConnectObject}->cluster()->health();
    };
    if ($@) {
        $Connect = 0;
    }

    # If engine was not reachable than treat it like an error for further fallbacks.
    if ( !$Connect ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Connection failed for engine: $Self->{Config}->{ActiveEngine}",
        );
        $Self->{ElasticSearch}->{Error} = 1;
        return;
    }

    return 1;
}

=head2 Disconnect()

TO-DO

=cut

sub Disconnect {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexAdd()

TO-DO

=cut

sub IndexAdd {
    my ( $Self, %Param ) = @_;

    return 1;
}

=head2 IndexDrop()

TO-DO

=cut

sub IndexDrop {
    my ( $Self, %Param ) = @_;

    return 1;
}

1;
