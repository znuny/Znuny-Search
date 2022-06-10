# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Engine::ES;

use strict;
use warnings;
use Search::Elasticsearch;

use parent qw( Kernel::System::Search::Engine );

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search::Mapping::ES',
);

=head1 NAME

Kernel::System::Search::Engine::ES - TO-DO

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

=head2 Connect()

TO-DO

=cut

sub Connect {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{Config} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need Config!"
        );
        return {
            Error => 1
        };
    }

    # try to receive information about cluster after connection.
    my $ConnectObject = Search::Elasticsearch->new(
        nodes => [
            '172.17.0.1:9200',    # MOCK-UP
        ]
    );

    eval {
        $ConnectObject->cluster()->health();
    };

    # If engine was not reachable than treat it like an error for further fallbacks.
    if ($@) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Connection failed for engine: $Self->{Config}->{ActiveEngine}. Message: $@",
        );
        return {
            Error => 1
        };
    }

    return $ConnectObject;
}

=head2 QueryExecute()

TO-DO

=cut

sub QueryExecute {
    my ( $Self, %Param ) = @_;

    my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');
    my $MappingObject = $Kernel::OM->Get('Kernel::System::Search::Mapping::ES');
    my $ConnectObject = $Param{ConnectObject};

    for my $Name (qw(Query Index QueryType ConnectObject)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return {
                Error => 1,
            };
        }
    }

    my $QueryType = $Param{QueryType};
    my $Result;

    eval {
        $Result = $ConnectObject->$QueryType(
            index => $Param{Index} || 'ticket',
            body  => {
                %{ $Param{Query} }
            }
        );
    };
    if ($@) {
        my $Engine = "Kernel::System::Search::Engine::ES";

        $LogObject->Log(
            Priority => 'error',
            Message  => "Query failed for engine: $Engine. Message: $@",
        );
        return {
            Error => 1,
        };
    }

    return $Result;
}

1;
