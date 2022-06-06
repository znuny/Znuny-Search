# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AdvancedSearch::Engine::ES;

use strict;
use warnings;
use Search::Elasticsearch;

use parent qw( Kernel::System::AdvancedSearch::Engine );

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::AdvancedSearch::Mapping::ES',
);

=head1 NAME

Kernel::System::AdvancedSearch::Engine::ES - TO-DO

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

    $Self->{ConnectObject} = Search::Elasticsearch->new(
        nodes => [
            '172.17.0.1:9200',    # MOCK-UP
        ]
    );

    # try to receive information about cluster after connection.
    eval {
        $Self->{ConnectObject}->cluster()->health();
    };
    if ($@) {
        $Self->{ConnectionError} = 1;
    }

    return $Self;
}

=head2 QueryExecute()

TO-DO

=cut

sub QueryExecute {
    my ( $Self, %Param ) = @_;

    my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');
    my $MappingObject = $Kernel::OM->Get('Kernel::System::AdvancedSearch::Mapping::ES');

    if ( !$Param{Query} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Missing query body."
        );
    }

    if ( $Self->{ConnectionError} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "A connection error has occurred",
        );

        return {
            ConnectionError => 1
        };
    }

    my $QueryType = $Param{QueryType} || 'search';

    my $Result = $Self->{ConnectObject}->$QueryType(
        index => $Param{Index},
        body  => {
            %{ $Param{Query} }
        }
    );

    # Globaly standarize format to understandable by search engine.
    $Result = $MappingObject->ResultFormat(
        Result => $Result
    );

    return $Result;
}

1;
