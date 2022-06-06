# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AdvancedSearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::AdvancedSearch - TO-DO

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

    $Self->{Config}->{ActiveEngine} = 'ES';    # MOCK-UP

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

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
    for my $Needed (qw(Objects)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
    }

    my $Result = $Self->QueryPrepare(%Param);

    if ( $Result->{Error} ) {
        $Result->{Fallback} = $Self->Fallback(%Param);
    }

    return $Result if !$Result->{Fallback}->{Continue};

    my @Queries = $Result->{Queries} || ();

    my $StructureMapping = {
        "Mapping" => "Kernel::System::AdvancedSearch::Mapping::$Self->{Config}->{ActiveEngine}",
        "Engine"  => "Kernel::System::AdvancedSearch::Engine::$Self->{Config}->{ActiveEngine}",
    };

    my %AdvancedSearchModules;
    for my $SearchStructureItem (qw ( Mapping Engine )) {
        $AdvancedSearchModules{$SearchStructureItem} = $Kernel::OM->Get( $StructureMapping->{$SearchStructureItem} );
    }

    my $QueriesToExecute;
    if ( scalar @Queries > 1 ) {
        $QueriesToExecute = $AdvancedSearchModules{Engine}->QueryMerge(
            Queries => \@Queries
        );
    }
    else {
        $QueriesToExecute = $Queries[0];
    }

    my @Result;
    for my $Query ( @{$QueriesToExecute} ) {
        my $ResultQuery = $AdvancedSearchModules{Engine}->QueryExecute(
            Query => $Query
        );

        push @Result, $ResultQuery;
    }

    my $Response = {};

    # TODO: Standarization of specific object response after claryfication of response from query execute.

    return $Response;

}

=head2 Connect()

TO-DO

=cut

sub Connect {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $Connect;

    # Connection process...

    # *Successfully*
    $Connect = 1;    # MOCK-UP

    # If engine was not reachable than treat it like an error for further fallbacks.
    if ( !$Connect ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Connection failed for engine: $Self->{ElasticSearch}->{ActiveEngine}",
        );
        $Self->{ElasticSearch}->{Error} = 1;
    }

    return $Connect;
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

=head2 QueryPrepare()

TO-DO

=cut

sub QueryPrepare {
    my ( $Self, %Param ) = @_;

    my %Result;

    my @Queries;

    OBJECTTYPE:
    for my $ObjectType ( sort keys %{ $Param{Objects} } ) {
        OBJECT:
        for my $Object ( @{ $Param{Objects}->{$ObjectType} } ) {
            my $ObjectModule = $Kernel::OM->Get("Kernel::System::AdvancedSearch::Object::${ObjectType}::${Object}");

            my $Data = $ObjectModule->Search(
                Param     => \%Param,
                IndexName => $Object,
                Node      => $ObjectType,
            );

            $Data = {    # MOCK-UP
                Error    => 0,
                Fallback => {
                    Continue => 1
                },
                Query => 'Queries 1'
            };

            $Result{Error}    = $Data->{Error};
            $Result{Fallback} = $Data->{Fallback};    # THIS POSSIBLE SHOULD SLICE RESPONSE PER OBJECT MODULE.

            # TODO: Check for possibility of handling fallbacks mixed with engine requests.
            last OBJECTTYPE if $Result{Error};

            push @Queries, $Data->{Query};
        }
    }

    $Result{Queries} = \@Queries;

    return \%Result;
}

=head2 Fallback()

TO-DO

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    my $Objects = $Param{Objects};

    my %Result;
    for my $ObjectType ( sort keys %{$Objects} ) {
        for my $Object ( @{ $Objects->{$ObjectType} } ) {
            $Result{$ObjectType}{$Object}
                = $Kernel::OM->Get("Kernel::System::AdvancedSearch::Object::${ObjectType}::${Object}")
                ->Fallback(%Param);
        }
    }

    return \%Result;
}

1;
