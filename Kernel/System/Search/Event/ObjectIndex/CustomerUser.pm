# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::CustomerUser;

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

    my $UserLogin = $Param{Data}->{UserLogin};

    # no complete data is sent in the event data
    # so there is a need to make an sql statement
    # by user login
    if ( $Param{Event} eq 'CustomerUserUpdate' ) {
        $UserLogin = $Param{Data}->{NewData}->{UserLogin};

        my $QueryParams = {
            UserLogin => $UserLogin,
        };

        return $SearchObject->ObjectIndexUpdate(
            Index       => 'CustomerUser',
            Refresh     => 1,
            QueryParams => $QueryParams,
        );
    }
    elsif ( $Param{Event} eq 'CustomerUserAdd' ) {
        my $QueryParams = {
            UserLogin => $UserLogin,
        };

        return $SearchObject->ObjectIndexAdd(
            Index       => 'CustomerUser',
            Refresh     => 1,
            QueryParams => $QueryParams,
        );
    }

    return 1;
}

1;
