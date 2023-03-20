# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::JSON',
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
    my $JSONObject        = $Kernel::OM->Get('Kernel::System::JSON');

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

    NEEDED:
    for my $Needed (qw(FunctionName IndexName)) {
        next NEEDED if $Param{Config}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed in Config!"
        );
        return;
    }

    my $IndexName              = $Param{Config}->{IndexName};
    my $IndexSearchObject      = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$IndexName");
    my $ObjectIdentifierColumn = $IndexSearchObject->{Config}->{Identifier};
    my $ObjectID               = $Param{Data}->{$ObjectIdentifierColumn};

    if ( !$ObjectID ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need ObjectID ($ObjectIdentifierColumn) in event Data!"
        );
        return;
    }

    my $AdditionalValueParameters;

    if ( $Param{Config}->{AdditionalValueParameters} ) {
        my $DecodedJSON = $JSONObject->Decode(
            Data => $Param{Config}->{AdditionalValueParameters},
        );

        $AdditionalValueParameters = $DecodedJSON;
    }

    $SearchChildObject->IndexObjectQueueAdd(
        Index => $IndexName,
        Value => {
            FunctionName         => $Param{Config}->{FunctionName},
            ObjectID             => $ObjectID,
            AdditionalParameters => $AdditionalValueParameters
        },
    );

    return 1;
}

1;
