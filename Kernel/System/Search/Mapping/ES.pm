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

our @ObjectDependencies = (
    'Kernel::Config',
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

    my $Result = $Param{Result};

    return {
        Reason => $Result->{reason},
        Status => $Result->{status},
        Type   => $Result->{type}
    } if $Result->{status};

    my $Objects = $Self->_PreProcessObjectTypes(
        Hits => $Result->{hits}->{hits}
    );

    return {
        Objects      => $Objects,
        Shards       => $Result->{_shards},
        ResponseTime => $Result->{took},
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

    for my $Param ( sort keys %{ $Param{SearchParams} } ) {

        my $Must = {
            match => {
                $Param => {
                    query => $Param{SearchParams}->{$Param}
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

sub _PreProcessObjectTypes {
    my ( $Self, %Param ) = @_;

    my $Hits         = $Param{Hits} || ();
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $SearchIndexMapping = $ConfigObject->Get("Search::Mapping");

    my %Objects;
    for my $Hit ( @{$Hits} ) {
        my $Object       = $SearchIndexMapping->{ $Hit->{_index} };
        my $ObjectConfig = $SearchIndexMapping->{$Object};
        push @{ $Objects{ $ObjectConfig->{ObjectType} }{ $ObjectConfig->{Index} } }, $Hit->{_source};
    }

    return \%Objects;
}

1;
