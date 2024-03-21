# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::FAQCategory;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

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

    return if $Param{Event} ne 'FAQSetCategoryGroup';

    my $IndexName    = 'FAQ';
    my $NewGroupsIDs = $Param{Data}->{GroupIDs};
    my $CategoryID   = $Param{Data}->{CategoryID};

    $SearchChildObject->IndexObjectQueueEntry(
        Index => $IndexName,
        Value => {
            Operation   => 'ObjectIndexUpdate',
            QueryParams => {
                CategoryID => $CategoryID,
            },
            Data => {
                CustomFunction => {
                    Name   => 'ObjectIndexUpdateGroupID',
                    Params => {
                        NewGroupID => $NewGroupsIDs,
                    }
                },
            },
            Context => "ObjectIndexUpdate_GroupReassign_${CategoryID}",
        },
    );

    return 1;
}

1;
