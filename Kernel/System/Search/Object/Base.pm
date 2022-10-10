# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Base;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsHashRefWithData IsArrayRefWithData);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::DB',
    'Kernel::Config',
    'Kernel::System::Search::Object::Operators',
    'Kernel::System::Search::Object',
);

=head1 NAME

Kernel::System::Search::Object::Base - common base backend functions

=head1 DESCRIPTION

Proceed with fallback, format operation response, load custom columns and
other base related functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchBaseObject = $Kernel::OM->Get('Kernel::System::Search::Object::Base');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    $LogObject->Log(
        Priority => 'error',
        Message  => "Constructor needs to be overriden!",
    );

    return $Self;
}

=head2 Fallback()

Fallback from using advanced search for specific index.

Should return same response as advanced search
engine globally formatted response.

    my $Result = $SearchBaseObject->Fallback(
        QueryParams  => {
            TicketID => 1,
        },
        Limit        => $Limit,
        OrderBy      => $OrderBy,
        SortBy       => $SortBy,
        ResultType   => $ResultType,
        Fields       => $Fields,
    );

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw( QueryParams )) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $SQLSearchResult = $Self->SQLObjectSearch(
        QueryParams => $Param{QueryParams},
        Limit       => $Param{Limit} || $Self->{DefaultSearchLimit},
        OrderBy     => $Param{OrderBy},
        SortBy      => $Param{SortBy},
        ResultType  => $Param{ResultType},
        Fields      => $Param{Fields},
        Silent      => $Param{Silent},
    );

    my $Result = {
        EngineData => {},
        ObjectData => $SQLSearchResult,
    };

    return $Result;
}

=head2 SQLObjectSearch()

search in sql database for objects index related

    my $Result = $SearchBaseObject->SQLObjectSearch(
        QueryParams => {
            TicketID => 1,
        },
        Fields      => ['TicketID', 'SLAID'] # optional, returns all
                                             # fields if not specified
        SortBy      => $IdentifierSQL,
        OrderBy     => "Down",  # possible: "Down", "Up",
        ResultType  => $ResultType,
        Limit       => 10
    );

TO-DO: delete later
Developer note: most conditions needs to be met with engine
alternative (Kernel/System/Search/Object/Query->Search()).

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw( QueryParams )) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $IndexRealName      = $Self->{Config}->{IndexRealName};
    my $Fields             = $Self->{Fields};
    my $SupportedOperators = $Self->{SupportedOperators};
    my $ResultType         = $Param{ResultType} || 'ARRAY';

    # prepare sql statement
    my $SQL;
    my @TableColumns;
    if ( $ResultType eq 'COUNT' ) {
        $SQL = 'SELECT COUNT(*) FROM ' . $IndexRealName;
    }
    else {
        # set columns that will be retrieved
        if ( IsArrayRefWithData( $Param{Fields} ) ) {
            my @ParamFields = @{ $Param{Fields} };
            for ( my $i = 0; $i < scalar @ParamFields; $i++ ) {
                $TableColumns[$i] = $Fields->{ $ParamFields[$i] }->{ColumnName};
            }
        }

        # not used anymore
        # TODO delete if really not used
        else {
            for my $Field ( sort keys %{$Fields} ) {
                push @TableColumns, $Fields->{$Field}->{ColumnName};
            }
        }
        $SQL = 'SELECT ' . join( ',', @TableColumns ) . ' FROM ' . $IndexRealName;
    }

    my @QueryParamValues = ();
    if ( IsHashRefWithData( $Param{QueryParams} ) ) {
        my @QueryConditions;

        # apply search params for columns that are supported
        PARAM:
        for my $QueryParam ( sort keys %{ $Param{QueryParams} } ) {

            # check if there is existing mapping between query param and database column
            next PARAM if !$Fields->{$QueryParam};

            # do not accept undef values for param
            next PARAM if !defined $Param{QueryParams}->{$QueryParam};

            my $QueryParamColumnName = $Fields->{$QueryParam}->{ColumnName};

            my $QueryParamType = $Fields->{$QueryParam}->{Type};

            my $QueryParamValue;
            my $QueryParamOperator;

            if ( ref $Param{QueryParams}->{$QueryParam} eq "HASH" ) {
                $QueryParamValue    = $Param{QueryParams}->{$QueryParam}->{Value};
                $QueryParamOperator = $Param{QueryParams}->{$QueryParam}->{Operator} || '=';
            }
            else {
                $QueryParamValue    = $Param{QueryParams}->{$QueryParam};
                $QueryParamOperator = "=";
            }

            if ( !$SupportedOperators->{$QueryParamType}->{Operator}->{$QueryParamOperator} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Operator '$QueryParamOperator' is not supported for '$QueryParamType' type.",
                );
                return;
            }

            my $OperatorModule = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");

            my $Result = $OperatorModule->OperatorQueryGet(
                Field    => $QueryParamColumnName,
                Value    => $QueryParamValue,
                Operator => $QueryParamOperator,
                Object   => $Self->{Config}->{IndexName},
                Fallback => 1,
            );

            if ( $Result->{Bindable} ) {
                $QueryParamValue = $Result->{BindableValue} if $Result->{BindableValue};
                push @QueryParamValues, \$QueryParamValue;
            }

            push @QueryConditions, $Result->{Query};
        }

        # apply WHERE clause only when there are
        # at least one valid query condition
        if ( scalar @QueryConditions ) {
            $SQL .= ' WHERE ' . join( ' AND ', @QueryConditions );
        }
    }

    # sort data
    # check if property is specified in the object fields
    if (
        $Param{SortBy} && $Self->{Fields}->{ $Param{SortBy} }
        )
    {
        # check if specified result type can be sorted
        my $Sortable = $Self->IsSortableResultType(
            ResultType => $ResultType,
        );

        # apply sort query
        if ($Sortable) {
            $SQL .= " ORDER BY $Self->{Fields}->{$Param{SortBy}}->{ColumnName}";
            if ( $Param{OrderBy} ) {
                if ( $Param{OrderBy} eq 'Up' ) {
                    $SQL .= " ASC";
                }
                else {
                    $SQL .= " DESC";
                }
            }
        }
        else {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Can't sort table: \"$Self->{Config}->{IndexRealName}\" with result type:" .
                        " \"$ResultType\" by field: \"$Param{SortBy}\"." .
                        " Specified result type is not sortable!\n" .
                        " Sort operation won't be applied."
                );
            }
        }
    }

    # apply limit query
    if ( $Param{Limit} ) {
        $SQL .= " LIMIT $Param{Limit}";
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@QueryParamValues
    );
    my @Result;

    if ( $ResultType eq 'COUNT' ) {
        my @Count = $DBObject->FetchrowArray();
        return $Count[0];
    }
    else {
        # save data in format: sql column name => sql column value
        while ( my @Row = $DBObject->FetchrowArray() ) {
            my %Data;
            my $DataCounter = 0;
            for my $RealNameColumn (@TableColumns) {
                $Data{$RealNameColumn} = $Row[$DataCounter];
                $DataCounter++;
            }
            push @Result, \%Data;
        }
    }

    return \@Result;
}

=head2 SearchFormat()

format result specifically for index

    my $FormattedResult = $SearchBaseObject->SearchFormat(
        ResultType => 'ARRAY|HASH|COUNT' (optional, default: 'ARRAY')
        IndexName  => "Ticket",
        GloballyFormattedResult => $GloballyFormattedResult,
    )

=cut

sub SearchFormat {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    my $ResultType = $Param{ResultType};

    # define supported result types
    my $SupportedResultTypes = $Self->{SupportedResultTypes};

    if ( !$SupportedResultTypes->{ $Param{ResultType} } ) {
        $LogObject->Log(
            Priority => 'error',
            Message =>
                "Specified result type: $Param{ResultType} isn't supported! Default value: \"ARRAY\" will be used instead.",
        );

        # revert to default result type
        $Param{ResultType} = 'ARRAY';
    }

    my $IndexName               = $Self->{Config}->{IndexName};
    my $GloballyFormattedResult = $Param{GloballyFormattedResult};

    # return only number of records without formatting its attribute
    if ( $Param{ResultType} eq "COUNT" ) {
        return {
            $IndexName => $GloballyFormattedResult->{$IndexName}->{ObjectData},
        };
    }

    my $IndexResponse;
    my @AttributeNames = @{ $Param{Fields} };

    my @ColumnNames;
    for my $FieldName (@AttributeNames) {
        push @ColumnNames, $Self->{Fields}->{$FieldName}->{ColumnName};
    }

    # fallback
    if ( $Param{Fallback} ) {
        OBJECT:
        for my $ObjectData ( @{ $GloballyFormattedResult->{$IndexName}->{ObjectData} } ) {
            @$ObjectData{@AttributeNames} = delete @$ObjectData{@ColumnNames};
        }
    }

    if ( $Param{ResultType} eq "ARRAY" ) {
        $IndexResponse->{$IndexName} = $GloballyFormattedResult->{$IndexName}->{ObjectData};
    }
    elsif ( $Param{ResultType} eq "HASH" ) {

        my $Identifier = $Self->{Config}->{Identifier};
        if ( !$Identifier ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Missing '\$Self->{Config}->{Identifier} for $IndexName index.'",
                );
            }
            return;
        }

        $IndexResponse = { $IndexName => {} };

        DATA:
        for my $Data ( @{ $GloballyFormattedResult->{$IndexName}->{ObjectData} } ) {
            if ( !$Data->{$Identifier} ) {
                if ( !$Param{Silent} ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message =>
                            "Could not get object identifier: $Identifier for index: $IndexName in the response!",
                    );
                }
                next DATA;
            }

            $IndexResponse->{$IndexName}->{ $Data->{$Identifier} } = $Data;
        }
    }

    return $IndexResponse;
}

=head2 ObjectIndexGetFormat()

=cut

sub ObjectIndexGetFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

=head2 ObjectIndexAddFormat()

=cut

sub ObjectIndexAddFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

=head2 ObjectIndexRemoveFormat()

=cut

sub ObjectIndexRemoveFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

=head2 ObjectIndexUpdateFormat()

=cut

sub ObjectIndexUpdateFormat {
    my ( $Self, %Param ) = @_;
    return {};
}

=head2 ObjectListIDs()

return all sql data of object ids

    my $ResultIDs = $SearchTicketObject->ObjectListIDs();

=cut

sub ObjectListIDs {
    my ( $Self, %Param ) = @_;

    my $IndexObject   = $Kernel::OM->Get("Kernel::System::Search::Object::$Self->{Config}->{IndexName}");
    my $Identifier    = $IndexObject->{Config}->{Identifier};
    my $IdentifierSQL = $IndexObject->{Fields}->{$Identifier}->{ColumnName};

    # search for all objects from newest, order it by id
    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams => {},
        Fields      => [$Identifier],
        OrderBy     => $Param{OrderBy},
        SortBy      => $Identifier,
        ResultType  => $Param{ResultType},
    );

    my @Result = ();

    # push hash data into array
    if ( IsArrayRefWithData($SQLSearchResult) ) {
        for my $SQLData ( @{$SQLSearchResult} ) {
            push @Result, $SQLData->{$IdentifierSQL};
        }
    }

    return \@Result;
}

=head2 CustomFieldsConfig()

get all registered custom field mapping for parent index module
or specified in parameter index

    $Config = $SearchBaseObject->CustomFieldsConfig();

=cut

sub CustomFieldsConfig {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Self->{Config}->{IndexName} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need IndexName!",
        );
    }

    my $CustomPackageModuleConfigList = $ConfigObject->Get(
        "Search::FieldsLoader::$Self->{Config}->{IndexName}"
    );

    my %CustomFieldsMapping = (
        Fields => {},
    );

    for my $CustomPackageConfig ( sort keys %{$CustomPackageModuleConfigList} ) {
        my $Module        = $CustomPackageModuleConfigList->{$CustomPackageConfig};
        my $PackageModule = $Kernel::OM->Get("$Module->{Module}");

        for my $Type (qw( Fields )) {
            %{ $CustomFieldsMapping{$Type} } = ( %{ $PackageModule->{$Type} }, %{ $CustomFieldsMapping{$Type} } );
        }
    }

    return \%CustomFieldsMapping;
}

=head2 DefaultConfigGet()

get default index config

    my $Success = $SearchBaseObject->DefaultConfigGet();

=cut

sub DefaultConfigGet {
    my ( $Self, %Param ) = @_;

    # define supported result types
    $Self->{SupportedResultTypes} = {

        # key defines if result type is supported
        'ARRAY' => {

            # sortable defines if sql/engine can use
            # OrderBy, SortBy parameters in queries
            Sortable => 1,
        },
        'HASH' => {
            Sortable => 0,
        },
        'COUNT' => {
            Sortable => 0,
        }
    };

    # define default limit for search query
    $Self->{DefaultSearchLimit} = 10000;

    $Self->{SupportedOperators} = {
        Date => {
            Operator => {
                ">="             => 1,
                "="              => 1,
                "!="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
            }
        },
        String => {
            Operator => {
                "="              => 1,
                "!="             => 1,
                ">="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
                "FULLTEXT"       => 1,
                "PATTERN"        => 1,
            }
        },
        Integer => {
            Operator => {
                ">="             => 1,
                "="              => 1,
                "!="             => 1,
                "<="             => 1,
                "<"              => 1,
                ">"              => 1,
                "IS EMPTY"       => 1,
                "IS NOT EMPTY"   => 1,
                "IS DEFINED"     => 1,
                "IS NOT DEFINED" => 1,
            }
        }
    };

    # define list of values for types which should be set as undefined while indexing.
    $Self->{DataTypeValuesBlackList} = {
        Date => [
            '0000-00-00 00:00:00',
            '1000-00-00 00:00:00',
        ]
    };

    return 1;
}

=head2 IsSortableResultType()

check if result type is sort-able

    my $Result = $SearchBaseObject->IsSortableResultType(
        ResultType => "ARRAY",
    );

=cut

sub IsSortableResultType {
    my ( $Self, %Param ) = @_;

    return $Self->{SupportedResultTypes}->{ $Param{ResultType} }->{Sortable} ? 1 : 0;
}

=head2 _Load()

load fields, custom field mapping

    my %FunctionResult = $SearchBaseObject->_Load(
        Fields => $Fields,
    );

=cut

sub _Load {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $Config       = $Self->CustomFieldsConfig();

    # load custom field mapping
    %{ $Self->{Fields} } = ( %{ $Param{Fields} }, %{ $Config->{Fields} } );

    $Self->{OperatorMapping} = $SearchObject->{DefaultOperatorMapping};

    return 1;
}

1;
