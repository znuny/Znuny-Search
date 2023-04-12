# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
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

    NEEDED:
    for my $Needed (qw(FunctionName)) {
        next NEEDED if $Param{Config}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed in Config!"
        );
        return;
    }

    my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
        Name => $Param{Data}->{FieldName},
    );

    return if !IsHashRefWithData($DynamicFieldConfig);

    # get type of data that are stored in db
    my $FieldValueTypeGet = $DynamicFieldBackendObject->TemplateValueTypeGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        FieldType          => 'Edit',
    );
    return if !IsHashRefWithData($FieldValueTypeGet);

    my $FieldValueType = $FieldValueTypeGet->{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
    my $FunctionName   = $Param{Config}->{FunctionName};
    my $Success;
    my $AdditionalParameters;
    my $IndexToUpdate;
    my $SearchQuery;
    my $ObjectID;

    # update ticket or customer user
    if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {
        $AdditionalParameters = {
            UpdateTicket => 1,
        };
        $IndexToUpdate = 'Ticket';
        $ObjectID      = $Param{Data}->{TicketID};
        $SearchQuery   = {
            ObjectID => $ObjectID,
        };
    }
    elsif ( $DynamicFieldConfig->{ObjectType} eq 'Article' ) {
        $AdditionalParameters = {
            UpdateArticle => [ $Param{Data}->{ArticleID} ],
        };
        $IndexToUpdate = 'Ticket';
        $ObjectID      = $Param{Data}->{ArticleID};
        $SearchQuery   = {
            ObjectID => $Param{Data}->{TicketID},
        };
    }
    elsif ( $DynamicFieldConfig->{ObjectType} eq 'CustomerUser' ) {
        $IndexToUpdate = 'CustomerUser';
        $ObjectID      = $Param{Data}->{ObjectName};
        $SearchQuery   = {
            QueryParams => {
                UserLogin => $ObjectID,
            }
        };
    }

    # create unique id
    my $UniqueID = 'f' . $DynamicFieldConfig->{ID} . 'o' . $ObjectID;

    # value was deleted - array & scalar fields support
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
        # update ticket/customer user index as it have dynamic fields stored as denormalized values
        # ticket does not need context as it does not use "QueryParams" parameter
        if ( $IndexToUpdate eq 'CustomerUser' ) {
            return $SearchObject->ObjectIndexUpdate(
                Index   => 'CustomerUser',
                Refresh => 1,
                %{$SearchQuery},
            );
        }
        else {
            my %Context;
            %Context = (
                Context => "ObjectIndexUpdate_DFDelete_$UniqueID"
            ) if !$SearchQuery->{ObjectID};
            return $SearchChildObject->IndexObjectQueueEntry(
                Index => $IndexToUpdate,
                Value => {
                    Operation => 'ObjectIndexUpdate',
                    Data      => $AdditionalParameters,
                    %Context,
                    %{$SearchQuery},
                },
            );
        }
    }

    # update ticket/customer user index as it have dynamic fields stored as denormalized values
    my $ParentIndexSuccess;
    if ( $IndexToUpdate eq 'CustomerUser' ) {
        $ParentIndexSuccess = $SearchObject->ObjectIndexUpdate(
            Index   => 'CustomerUser',
            Refresh => 1,
            %{$SearchQuery},
        );
    }
    else {
        my %Context;
        %Context = (
            Context => "ObjectIndexUpdate_DFValueChanged_$UniqueID",
        ) if !$SearchQuery->{ObjectID};

        $ParentIndexSuccess = $SearchChildObject->IndexObjectQueueEntry(
            Index => $IndexToUpdate,
            Value => {
                Operation => 'ObjectIndexUpdate',
                Data      => $AdditionalParameters,
                %Context,
                %{$SearchQuery},
            },
        );
    }

    $Success = $ParentIndexSuccess if $Success;

    return $Success;
}

1;
