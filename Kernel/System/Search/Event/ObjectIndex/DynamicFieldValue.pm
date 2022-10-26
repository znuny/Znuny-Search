# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::DynamicFieldValue;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicFieldValue',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed parameters
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    for my $Needed (qw(FunctionName)) {
        if ( !$Param{Config}->{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed in Config!"
            );
            return;
        }
    }

    my $SearchObject            = $Kernel::OM->Get('Kernel::System::Search');
    my $DynamicFieldObject      = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');

    return if $SearchObject->{Fallback};

    my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
        Name => $Param{Data}->{FieldName},
    );

    my $DynamicFieldValue = $DynamicFieldValueObject->ValueGet(
        FieldID  => $DynamicField->{ID},
        ObjectID => $Param{Data}->{ $Param{Config}->{Field} }
    );

    my $FunctionName = $Param{Config}->{FunctionName};

    my $Result = $SearchObject->$FunctionName(
        Index    => 'DynamicFieldValue',
        ObjectID => $DynamicFieldValue->[0]->{ID}
    );

    return 1;
}

1;
