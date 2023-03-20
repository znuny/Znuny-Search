# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::CustomerUser;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Default::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Main',
    'Kernel::System::Search',
);

=head1 NAME

Kernel::System::Search::Object::Query::CustomerUser - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchQueryCustomerUserObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::CustomerUser');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::CustomerUser');

    for my $Property (
        qw(Fields SupportedOperators OperatorMapping DefaultSearchLimit
        SupportedResultTypes Config ExternalFields SearchableFields )
        )
    {
        $Self->{ 'Index' . $Property } = $IndexObject->{$Property};
    }

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    $Self->{ActiveEngine} = $SearchObject->{Config}->{ActiveEngine};

    $MainObject->Require(
        "Kernel::System::Search::Object::EngineQueryHelper::$Self->{ActiveEngine}",
    );

    bless( $Self, $Type );

    return $Self;
}

=head2 _QueryFieldDataSet()

set data for field

    my $Result = $SearchQueryTicketObject->_QueryFieldDataSet(
        Name => 'SLAID',
    );

=cut

sub _QueryFieldDataSet {
    my ( $Self, %Param ) = @_;

    my $DefaultValue = {
        ReturnType => 'SCALAR',
    };
    my $Data = $DefaultValue;

    if ( $Param{Name} eq '_id' ) {
        $Data->{Type} = 'String';
        return $DefaultValue;
    }

    if ( $Self->{IndexFields}->{ $Param{Name} } ) {
        for my $Property (qw(Type ReturnType)) {
            if ( $Self->{IndexFields}->{ $Param{Name} }->{$Property} ) {
                $Data->{$Property} = $Self->{IndexFields}->{ $Param{Name} }->{$Property};
            }
        }
    }
    elsif ( $Self->{IndexExternalFields}->{ $Param{Name} } ) {
        for my $Property (qw(Type ReturnType)) {
            if ( $Self->{IndexExternalFields}->{ $Param{Name} }->{$Property} ) {
                $Data->{$Property} = $Self->{IndexExternalFields}->{ $Param{Name} }->{$Property};
            }
        }
    }

    # get information about query param if field
    # matches specified regexp
    elsif ( $Param{Name} =~ m{\A(?:DynamicField_(.+))} ) {
        my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        my $DynamicFieldName = $1 || $2;

        # get single dynamic field config
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => $DynamicFieldName,
        );

        # get object - "CustomerUser"
        my $ObjectType = $DynamicFieldConfig->{ObjectType};

        if ( !$ObjectType || $ObjectType ne 'CustomerUser' ) {
            return {
                Invalid => 1,
            };
        }

        if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {
            my $Info = $Self->_QueryDynamicFieldInfoGet(
                ObjectType         => $ObjectType,
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            $Data = $Info;
        }

        # dynamic field probably does not exists
        # determine if query is prepared for engine
        # if yes, then there is no need to get it validated
        # as at this time Znuny does not contain this dynamic field
        # but advanced engine have it saved
        elsif ( $Param{QueryFor} && $Param{QueryFor} eq 'Engine' ) {

            # apply the least restricted data
            return {
                ColumnName => 'DynamicField' . $DynamicFieldName,
                Name       => $DynamicFieldName,
                ReturnType => 'SCALAR',
                Type       => 'String',
            };
        }
    }

    return $Data;
}

sub _QueryFieldCheck {
    my ( $Self, %Param ) = @_;

    return   if $Param{Data} && $Param{Data}->{Invalid};
    return 1 if $Param{Name} =~ m{\A(DynamicField_.+)};
    return $Self->SUPER::_QueryFieldCheck(%Param);
}

1;
