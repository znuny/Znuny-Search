# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Query::DynamicFieldValue;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Query );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Object::Default::DynamicFieldValue',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
);

=head1 NAME

Kernel::System::Search::Object::Query::DynamicFieldValue - Functions to build query for specified operations

=head1 DESCRIPTION

Common search engine query backend functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $QueryDynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::DynamicFieldValue');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};

    my $IndexObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::DynamicFieldValue');

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

=head2 ObjectIndexAdd()

create query for specified operation

    my $Result = $SearchQueryObject->ObjectIndexAdd(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
        QueryParams     => $QueryParams,
    );

=cut

sub ObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(MappingObject)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    if ( $Param{ObjectID} && $Param{QueryParams} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter ObjectID and QueryParams cannot be used together!",
        );
        return;
    }
    elsif ( !$Param{ObjectID} && !$Param{QueryParams} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} :
        {
        $Identifier => $Param{ObjectID}
        };

    my $Fields = [ 'ID', 'ObjectID', 'FieldID', 'ValueText', 'ValueDate', 'ValueInt' ];

    my %CustomIndexFields = ( %{ $IndexObject->{Fields} }, %{ $IndexObject->{Config}->{AdditionalOTRSFields} } );

    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams       => $QueryParams,
        ResultType        => $Param{SQLSearchResultType} || 'ARRAY',
        Fields            => $Fields,
        CustomIndexFields => \%CustomIndexFields,
    );

    return if !IsArrayRefWithData($SQLSearchResult);

    $SQLSearchResult = $Self->_PrepareDFSQLResponse(
        SQLSearchResult => $SQLSearchResult,
        Index           => $Param{Index},
    );

    for my $ValueColumn (qw(ValueText ValueDate ValueInt)) {
        for my $Row ( @{$SQLSearchResult} ) {
            my $Value = delete $Row->{ $IndexObject->{Config}->{AdditionalOTRSFields}->{$ValueColumn}->{ColumnName} };
            $Row->{value} = $Value if defined $Value;
            $Row->{_ID}   = 'f' . $Row->{field_id} . 'o' . $Row->{object_id};
        }
    }

    # build and return query
    return $Param{MappingObject}->ObjectIndexAdd(
        %Param,
        Body => $SQLSearchResult,
    );
}

=head2 ObjectIndexSet()

create query for specified operation

    my $Result = $SearchQueryObject->ObjectIndexSet(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
    );

=cut

sub ObjectIndexSet {
    my ( $Self, %Param ) = @_;

    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    NEEDED:
    for my $Needed (qw(MappingObject)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    if ( $Param{ObjectID} && $Param{QueryParams} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter ObjectID and QueryParams cannot be used together!",
        );
        return;
    }
    elsif ( !$Param{ObjectID} && !$Param{QueryParams} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter ObjectID or QueryParams is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} :
        {
        $Identifier => $Param{ObjectID}
        };

    my $Fields = [ 'ID', 'ObjectID', 'FieldID', 'ValueText', 'ValueDate', 'ValueInt' ];

    my %CustomIndexFields = ( %{ $IndexObject->{Fields} }, %{ $IndexObject->{Config}->{AdditionalOTRSFields} } );

    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams       => $QueryParams,
        ResultType        => $Param{SQLSearchResultType} || 'ARRAY',
        Fields            => $Fields,
        CustomIndexFields => \%CustomIndexFields,
    );

    return if !IsArrayRefWithData($SQLSearchResult);

    $SQLSearchResult = $Self->_PrepareDFSQLResponse(
        SQLSearchResult => $SQLSearchResult,
        Index           => $Param{Index},
    );

    # build and return query
    return $Param{MappingObject}->ObjectIndexSet(
        %Param,
        Body => $SQLSearchResult,
    );
}

=head2 ObjectIndexRemove()

create query for specified operation

    my $Result = $SearchQueryObject->ObjectIndexRemove(
        MappingObject   => $Config,
        ObjectID        => $ObjectID,
        Config          => $Config,
        Index           => $Index,
        Body            => $Body,
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Config Index)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} :
        {
        $Identifier => $Param{ObjectID}
        };

    my $NoMappingCheck;
    my %FieldsDefinition = %{ $Self->{IndexFields} };
    if ( $QueryParams->{_id} ) {
        $NoMappingCheck = 1;
        $FieldsDefinition{_id}->{ColumnName} = '_id';
    }

    $QueryParams = $Self->_QueryParamsPrepare(
        QueryParams    => $QueryParams,
        NoMappingCheck => $NoMappingCheck,
    );

    # build and return query
    return $Param{MappingObject}->ObjectIndexRemove(
        %Param,
        FieldsDefinition => \%FieldsDefinition,
        QueryParams      => $QueryParams,
    );
}

=head2 IndexMappingSet()

create query for index mapping set operation

    my $Result = $SearchQueryObject->IndexMappingSet(
        MappingObject   => $MappingObject,
    );

=cut

sub IndexMappingSet {
    my ( $Self, %Param ) = @_;

    return if !$Param{MappingObject};

    my $Fields = $Self->{IndexFields};

    return if !IsHashRefWithData($Fields);

    for my $Column (qw(ValueText ValueDate ValueInt)) {
        delete $Fields->{$Column};
    }

    # returns the query
    return $Param{MappingObject}->IndexMappingSet(
        %Param,
        Fields      => $Fields,
        IndexConfig => $Self->{IndexConfig},
    );
}

=head2 _PrepareDFSQLResponse()

prepare dynamic field sql search response to be converted for de-normalized data

    my $SQLSearchResult = $SearchQueryObject->_PrepareDFSQLResponse(
        SQLSearchResult => $SQLSearchResult
    );

=cut

sub _PrepareDFSQLResponse {
    my ( $Self, %Param ) = @_;

    my $SQLSearchResult = $Param{SQLSearchResult};
    my $IndexObject     = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");

    # get all dynamic fields types to identify if response should contain array or scalar
    my %DynamicFieldTypes = map { $_->{field_id} => 1 } @{$SQLSearchResult};

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    for my $DynamicFieldID ( sort keys %DynamicFieldTypes ) {
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            ID => $DynamicFieldID,
        );

        my $DynamicFieldColumnName = 'DynamicField_' . $DynamicFieldConfig->{Name};

        my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            FieldType          => 'Edit',
        );

        $DynamicFieldTypes{$DynamicFieldID} = $FieldValueType->{$DynamicFieldColumnName};
    }

    for my $Row ( @{$SQLSearchResult} ) {
        for my $ValueColumn (qw(ValueText ValueDate ValueInt)) {
            my $Value = delete $Row->{ $IndexObject->{Config}->{AdditionalOTRSFields}->{$ValueColumn}->{ColumnName} };
            $Row->{value} = $Value if defined $Value;
            $Row->{_ID}   = 'f' . $Row->{field_id} . 'o' . $Row->{object_id};
        }
    }

    my %RowArray;
    my $Counter = 0;

    # convert array type of dynamic fields to an array response value
    for my $Row ( @{$SQLSearchResult} ) {
        my $RowID = $Row->{_ID};
        if ( $DynamicFieldTypes{ $Row->{field_id} } && $DynamicFieldTypes{ $Row->{field_id} } eq 'ARRAY' ) {
            if ( defined $RowArray{$RowID} ) {
                push @{ $SQLSearchResult->[ $RowArray{$RowID} ]->{value} }, $Row->{value};
                delete $SQLSearchResult->[$Counter];
            }
            else {
                $Row->{value} = [ $Row->{value} ];
                $RowArray{$RowID} = $Counter;
            }
        }
        $Counter++;
    }

    # clear response from undefined values that was deleted above
    @{$SQLSearchResult} = grep {$_} @{$SQLSearchResult};

    return $SQLSearchResult;
}
1;
