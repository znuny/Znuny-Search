# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::Ticket::DynamicFieldValue;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject                 = $Kernel::OM->Get('Kernel::System::Log');
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $SearchChildObject         = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    return if $SearchObject->{Fallback};

    NEEDED:
    for my $Needed (qw(Data Event Config)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $TicketID = $Param{Data}->{TicketID};
    return 1 if !$TicketID;

    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'Ticket',
    );

    my @QueryParamsID;
    for my $DynamicField ( @{$DynamicFieldList} ) {
        push @QueryParamsID, 'f' . $DynamicField->{ID} . 'o' . $TicketID;
    }
    return 1 if !scalar @QueryParamsID;

    $SearchChildObject->IndexObjectQueueAdd(
        Index => 'DynamicFieldValue',
        Value => {
            FunctionName => 'ObjectIndexRemove',
            QueryParams  => {
                _id => \@QueryParamsID,
            },
        },
    );

    return 1;
}

1;
