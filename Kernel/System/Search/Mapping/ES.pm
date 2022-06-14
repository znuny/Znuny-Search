# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Mapping::ES;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Mapping );

use Kernel::System::VariableCheck qw(IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log'
);

=head1 NAME

Kernel::System::Search::Mapping::ES - TO-DO

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

    return $Self;
}

=head2 ResultFormat()

TO-DO

=cut

sub ResultFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    NEEDED:
    for my $Needed (qw(Result Config IndexName)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing param: $Needed",
        );
        return;
    }

    my $IndexName = $Param{IndexName};
    my $Result    = $Param{Result};

    return {
        Reason => $Result->{reason},
        Status => $Result->{status},
        Type   => $Result->{type}
    } if $Result->{status};

    my $GloballyFormattedObjData = $Self->ResponseDataFormat(
        Hits => $Result->{hits}->{hits}
    );

    return {
        "$IndexName" => {
            ObjectData => $GloballyFormattedObjData,
            EngineData => {
                Shards       => $Result->{_shards},
                ResponseTime => $Result->{took},
            }
        }
    };
}

=head2 Search()

TO-DO

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # Empty query template.
    my %Query = (
        query => {
            bool => {}
        }
    );

    for my $Param ( sort keys %{ $Param{QueryParams} } ) {

        my $Must = {
            match => {
                $Param => {
                    query => $Param{QueryParams}->{$Param}
                }
            }
        };

        push @{ $Query{query}{bool}{must} }, $Must;
    }

    # $Query{query} = { # E.Q. initial Query
    #     query=>{
    #         bool => {
    #             must => [
    #                 {
    #                     match => {
    #                         Owner =>{
    #                             query => "Kamil Furtek"
    #                         }
    #                     }
    #                 },
    #                 {
    #                     match => {
    #                         Responsible =>{
    #                             query => "Kamil Furtek"
    #                         }
    #                     }
    #                 }
    #             ]
    #         }
    #     }
    # }

    return \%Query;
}

=head2 ResponseDataFormat()

globally formats response data from engine

=cut

sub ResponseDataFormat {
    my ( $Self, %Param ) = @_;

    return [] if !IsArrayRefWithData( $Param{Hits} );

    my $Hits = $Param{Hits};

    my @Objects;

    # ES engine response stores objects inside _source key
    for my $Hit ( @{$Hits} ) {
        push @Objects, $Hit->{_source};
    }

    return \@Objects;
}

1;
