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
    'Kernel::System::DynamicField::Backend',
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

    my $SearchObject              = $Kernel::OM->Get('Kernel::System::Search');
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    return if $SearchObject->{Fallback};

    # get dynamic field
    my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
        Name => $Param{Data}->{FieldName},
    );

    # get type of data that are stored in db
    my $FieldValueTypeGet = $DynamicFieldBackendObject->TemplateValueTypeGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        FieldType          => 'Edit',
    );
    my $FieldValueType = $FieldValueTypeGet->{ 'DynamicField_' . $DynamicFieldConfig->{Name} };

    my $FunctionName = $Param{Config}->{FunctionName};

    # array & scalar fields support
    if (
        ( $Param{Data}->{OldValue} && !( $Param{Data}->{Value} ) )
        ||
        (
            $FieldValueType
            && $FieldValueType eq 'ARRAY'
            && IsArrayRefWithData( $Param{Data}->{OldValue} )
            && !IsArrayRefWithData( $Param{Data}->{Value} )
        )
        )
    {
        # dynamic_field_value removal is problematic as otrs won't send here
        # id of record to delete, so instead custom id is defined for
        # advanced search engine
        $SearchObject->ObjectIndexRemove(
            Index => 'DynamicFieldValue',

            # use customized id which contains of "f*field_id*o*object_id*"
            QueryParams => {
                _id => 'f' . $DynamicFieldConfig->{ID} . 'o' . $Param{Data}->{TicketID},
            },
        );

        # update "Ticket" index as it also have dynamic fields as denormalized values
        $SearchObject->ObjectIndexSet(
            Index    => 'Ticket',
            ObjectID => $Param{Data}->{TicketID},
        );

        return 1;
    }

    $SearchObject->$FunctionName(
        Index       => 'DynamicFieldValue',
        QueryParams => {
            FieldID  => $DynamicFieldConfig->{ID},
            ObjectID => $Param{Data}->{TicketID},
        },
    );

    $SearchObject->ObjectIndexSet(
        Index    => 'Ticket',
        ObjectID => $Param{Data}->{TicketID},
    );

    return 1;
}

1;
