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

use Kernel::System::VariableCheck qw(:all);

use parent qw( Kernel::System::Search::Object::Query );

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Default::Ticket',
    'Kernel::System::Log',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
);

=head1 NAME

Kernel::System::Search::Object::Query::Ticket - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $QueryTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Ticket');

    # get index specified fields
    $Self->{IndexFields}               = $IndexObject->{Fields};
    $Self->{IndexSupportedOperators}   = $IndexObject->{SupportedOperators};
    $Self->{IndexOperatorMapping}      = $IndexObject->{OperatorMapping};
    $Self->{IndexDefaultSearchLimit}   = $IndexObject->{DefaultSearchLimit};
    $Self->{IndexSupportedResultTypes} = $IndexObject->{SupportedResultTypes};
    $Self->{IndexConfig}               = $IndexObject->{Config};

    bless( $Self, $Type );

    return $Self;
}

=head2 Search()

create query for specified operation

    my $Result = $SearchQueryObject->Search(
        MappingObject   => $Config,
        QueryParams     => $QueryParams,
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    return {
        Error    => 1,
        Fallback => {
            Enable => 1
        },
    } if !$Param{MappingObject};

    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $ParamSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Object}");

    if ( IsArrayRefWithData( $Param{AdvancedQueryParams} ) ) {

        # return the query
        my $Query = $Param{MappingObject}->AdvancedSearch(
            Limit => $Self->{IndexDefaultSearchLimit},    # default limit or override with limit from param
            %Param,
        );

        if ( !$Query ) {
            return {
                Error    => 1,
                Fallback => {
                    Enable => 1,
                },
            };
        }

        return {
            Query => $Query,
        };
    }

    my $SortBy;
    if (
        $Param{SortBy} && $Self->{IndexFields}->{ $Param{SortBy} }
        )
    {
        my $Sortable = $ParamSearchObject->IsSortableResultType(
            ResultType => $Param{ResultType},
        );

        if ($Sortable) {

            # change into real column name
            $SortBy = $Self->{IndexFields}->{ $Param{SortBy} };
        }
        else {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Can't sort index: \"$ParamSearchObject->{Config}->{IndexName}\" with result type:" .
                        " \"$Param{ResultType}\" by field: \"$Param{SortBy}\"." .
                        " Specified result type is not sortable!\n" .
                        " Sort operation won't be applied."
                );
            }
        }
    }

    my $SearchIndexObject
        = $Kernel::OM->Get("Kernel::System::Search::Object::$Param{Config}->{ActiveEngine}::$Param{Object}");

    return $SearchIndexObject->QuerySearch(
        Limit => $Self->{IndexDefaultSearchLimit},    # default limit or override with limit from param
        %Param,
        Fields           => $Param{Fields},
        FieldsDefinition => $Self->{IndexFields},
        QueryParams      => $Param{QueryParams},
        SortBy           => $SortBy,
    );
}

=head2 _QueryFieldCheck()

check specified field for index

    my $Result = $SearchQueryObject->_QueryFieldCheck(
        Name => 'SLAID',
        Value => '1', # by default value is passed but is not used
                      # in standard query module
    );

=cut

sub _QueryFieldCheck {
    my ( $Self, %Param ) = @_;

    return 1 if $Param{Name} =~ /DynamicField_+/;

    # by default check if field is in index fields and mapping check is enabled
    return if !$Self->{IndexFields}->{ $Param{Name} } && !$Param{NoMappingCheck};
    return 1;
}

=head2 _QueryFieldReturnTypeSet()

check specified return type field for index

    my $Result = $SearchQueryObject->_QueryFieldReturnTypeSet(
        Name => 'SLAID',
    );

=cut

sub _QueryFieldReturnTypeSet {
    my ( $Self, %Param ) = @_;

    if ( $Param{Name} =~ /DynamicField_(.+)/ ) {
        my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => $1,
        );

        my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            FieldType          => 'Edit',
        );

        return $FieldValueType->{"DynamicField_$1"} || 'SCALAR';
    }

    # return type is either specified or scalar
    return $Self->{IndexFields}->{ $Param{Name} }->{ReturnType} || 'SCALAR';
}

1;
