# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Event::ObjectIndex::DynamicField;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Search',
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

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    return if $SearchObject->{Fallback};

    my $FunctionName = $Param{Config}->{FunctionName};

    my $Result = $SearchObject->$FunctionName(
        Index    => 'DynamicField',
        ObjectID => $Param{Data}->{NewData}->{ID}
    );

    # deleting dynamic field definition triggers event
    # dynamic field delete but does not trigger dynamic field value delete
    # even when sql engine delete them
    # delete dynamic field with dynamic field value data from advanced engine
    if ( $FunctionName eq 'ObjectIndexRemove' ) {

        $SearchObject->ObjectIndexRemove(
            Index       => 'DynamicFieldValue',
            QueryParams => {
                FieldID => $Param{Data}->{NewData}->{ID}
            }
        );
    }

    return 1;
}

1;
