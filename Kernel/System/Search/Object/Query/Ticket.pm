# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::Ticket;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Ticket',
    'Kernel::Config',
    'Kernel::System::Log'
);

=head1 NAME

Kernel::System::Search::Object::Query::Ticket - Functions to build query for specified operations

=head1 DESCRIPTION

TO-DO

=head1 PUBLIC INTERFACE


=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $QueryTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketFields = $ConfigObject->Get('Search::Fields::Ticket');

    # get index specified fields
    my $IndexFields;
    for my $Key ( sort keys %{$TicketFields} ) {
        for my $InnerKey ( sort keys %{ $TicketFields->{$Key} } ) {
            $IndexFields->{$InnerKey} = 1;
        }
    }

    $Self->{IndexFields} = $IndexFields;

    bless( $Self, $Type );

    return $Self;
}

=head2 ObjectIndexAdd()

create query for specified operation

    my $Result = $QueryTicketObject->ObjectIndexAdd(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(MappingObject ObjectID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return {
            Error    => 1,
            Fallback => {
                Enable => 0
            },
        };
    }

    my $MappingObject = $Param{MappingObject};

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{ObjectID}
    );

    if ( !%Ticket ) {

        $LogObject->Log(
            Priority => 'error',
            Message  => "No ticket with the specified ID: $Param{ObjectID}",
        );

        return {
            Error    => 1,
            Fallback => {
                Enable => 0
            },
        };

    }

    # set only index specified fields
    for my $Key ( sort keys %Ticket ) {
        if ( !$Self->{IndexFields}{$Key} ) {
            delete $Ticket{$Key};
        }
    }

    # Returns the query
    my $Query = $MappingObject->ObjectIndexAdd(
        %Param,
        Body => \%Ticket
    );

    if ( !$Query ) {

        # TO-DO
    }

    return {
        Error    => 0,
        Query    => $Query,
        Fallback => {
            Enable => 0
        },
    };
}

=head2 ObjectIndexUpdate()

create query for specified operation

    my $Result = $QueryTicketObject->ObjectIndexUpdate(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(MappingObject ObjectID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return {
            Error    => 1,
            Fallback => {
                Enable => 0
            },
        };
    }

    my $MappingObject = $Param{MappingObject};

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{ObjectID}
    );

    if ( !%Ticket ) {

        $LogObject->Log(
            Priority => 'error',
            Message  => "No ticket with the specified ID: $Param{ObjectID}",
        );

        return {
            Error    => 1,
            Fallback => {
                Enable => 0
            },
        };

    }

    # set only index specified fields
    for my $Key ( sort keys %Ticket ) {
        if ( !$Self->{IndexFields}{$Key} ) {
            delete $Ticket{$Key};
        }
    }

    # Returns the query
    my $Query = $MappingObject->ObjectIndexUpdate(
        %Param,
        Body => \%Ticket
    );

    if ( !$Query ) {

        # TO-DO
    }

    return {
        Error    => 0,
        Query    => $Query,
        Fallback => {
            Enable => 0
        },
    };
}

1;
