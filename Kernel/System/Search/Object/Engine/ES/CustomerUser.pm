# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object::Engine::ES::CustomerUser;

use strict;
use warnings;

use parent qw( Kernel::System::Search::Object::Default::CustomerUser );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
    'Kernel::System::Search::Object::Operators',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::Search::Object::Engine::ES::CustomerUser - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

Important!

Usage of CustomerUser backend can be set by changing configuration in
file "Kernel/Config/Defaults.pm":
- copy/override your configuration for DB backend,
that is $Self->{CustomerUser}, $Self->{CustomerUser1}, etc. in a way that it
will have higher priority,
- change inside new config ($Self->{CustomerUser}) "Name" to "Elasticsearch Backend" (optional),
- additionally change "Module" to "Kernel::System::CustomerUser::Elasticsearch",
- add "CustomerUserEmailTypeFields" as a list
of fields that are supposed to be an emails, example:
    ..
    CustomerUserEmailTypeFields => {
        'email' => 1,
    },
    ..

Elasticsearch should work for CustomerSearch in the system, if it's not enabled/connected
it will fallback to DB module.

=head1 PUBLIC INTERFACE

=head2 new()

Don' t use the constructor directly, use the ObjectManager instead :

        my $SearchCustomerUserESObject = $Kernel::OM->Get('Kernel::System::Search::Object::Engine::ES::CustomerUser');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Module} = 'Kernel::System::Search::Object::Engine::ES::CustomerUser';

    # specify base config for index
    $Self->{Config} = {
        IndexRealName        => 'customer_user',    # index name on the engine/sql side
        IndexName            => 'CustomerUser',     # index name on the api side
        Identifier           => 'ID',               # column name that represents object id in the field mapping
        ChangeTimeColumnName => 'ChangeTime',       # column representing time of updated data entry
    };

    # load settings for index
    $Self->{Config}->{Settings} = $Self->LoadSettings(
        IndexName => $Self->{Config}->{IndexName},
    );

    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$CustomerUserObject->{"CustomerUser$Count"};

        my $CustomerUserMap = $CustomerUserObject->{"CustomerUser$Count"}->{CustomerUserMap};

        # find first customer user Elasticsearch config
        my $CustomerUserMapModule = $CustomerUserMap->{Module};
        if ( $CustomerUserMapModule && $CustomerUserMapModule eq 'Kernel::System::CustomerUser::Elasticsearch' ) {
            $Self->{ActiveDBBackend} = $CustomerUserObject->{"CustomerUser$Count"};
            $Self->{ActiveDBBackend}->{ValidBackend} = 1;
            last SOURCE;
        }
    }

    my %SchemaData;
    my @SchemaMap = ();
    if ( IsArrayRefWithData( $Self->{ActiveDBBackend} && $Self->{ActiveDBBackend}->{CustomerUserMap}->{Map} ) ) {
        @SchemaMap = @{ $Self->{ActiveDBBackend}->{CustomerUserMap}->{Map} };
    }

    my %TypeMapping = (
        var => 'String',
        int => 'Integer',
    );

    my $EmailFields = $Self->{ActiveDBBackend}->{CustomerUserMap}->{CustomerUserEmailTypeFields};

    for my $ColumnDefinition (@SchemaMap) {

        # filter out dynamic fields in the mapping
        my $ColumnData = {
            ColumnName => $ColumnDefinition->[2],
            Type       => $TypeMapping{ $ColumnDefinition->[5] } || 'String',
            Alias      => 1,
            ReturnType => 'SCALAR',
        };

        if ( $EmailFields->{ $ColumnDefinition->[2] } ) {
            $ColumnData->{Type} = 'Email';
        }

        if ( $ColumnDefinition->[0] !~ m{\ADynamicField_.*\z} ) {
            $SchemaData{ $ColumnDefinition->[0] } = $ColumnData;
        }
        else {
            push @{ $Self->{DynamicFields}->{ $ColumnDefinition->[0] } }, $ColumnDefinition;
        }
    }

    if ( !$Self->{ActiveDBBackend}->{CustomerUserMap}->{Params}->{ForeignDB} ) {
        $SchemaData{CreateTime} = {
            ColumnName => 'create_time',
            Type       => 'Date',
            ReturnType => 'SCALAR',
        };
        $SchemaData{CreateBy} = {
            ColumnName => 'create_by',
            Type       => 'Integer',
            ReturnType => 'SCALAR',
        };
        $SchemaData{ChangeTime} = {
            ColumnName => 'change_time',
            Type       => 'Date',
            ReturnType => 'SCALAR',
        };
        $SchemaData{ChangeBy} = {
            ColumnName => 'change_by',
            Type       => 'Integer',
            ReturnType => 'SCALAR',
        };
    }

    # define schema for data
    my $FieldMapping = {
        ID => {
            ColumnName => 'id',
            Type       => 'Integer',
            ReturnType => 'SCALAR',
        },
        %SchemaData,
    };

    # get default config
    $Self->DefaultConfigGet();

    # load fields with custom field mapping
    $Self->_Load(
        Fields => $FieldMapping,
        Config => $Self->{Config},
    );

    return $Self;
}

=head2 Search()

Prepare data and parameters for engine or fallback search,
then execute search.

    my $Result = $SearchCustomerUserESObject->Search(
        ID            => $Param{CustomerUserID},
        Objects       => ['CustomerUser'],
        Counter       => $Counter,
        MappingObject => $MappingObject},
        EngineObject  => $EngineObject},
        ConnectObject => $ConnectObject},
        GlobalConfig  => $Config},
    );

    my $Result = $Kernel::OM->Get('Kernel::System::Search')->Search(
        Objects => ["CustomerUser"],
        QueryParams => {
            # standard CustomerUser fields
            ID => 1,

            # CustomerUser dynamic fields
            DynamicField_Text => 'TextValue',
            DynamicField_Multiselect => [1,2,3],
        },
        Fields => [['CustomerUser_CustomerUserID', 'CustomerUser_CustomerUserNumber']] # specify field from field mapping
            # to get:
            # - CustomerUser fields (all): [['CustomerUser_*']]
            # - CustomerUser field (specified): [['CustomerUser_CustomerUserID', 'CustomerUser_Title']]
            # - CustomerUser dynamic fields (all): [['CustomerUser_DynamicField_*']]
            # - CustomerUser dynamic fields (specified): [['CustomerUser_DynamicField_multiselect', 'CustomerUser_DynamicField_dropdown']]
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    if ( !$Self->{ActiveDBBackend} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Active customer user Elasticsearch backend was not found!"
        );
        return $Self->SearchEmptyResponse(%Param);
    }

    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $UserObject        = $Kernel::OM->Get('Kernel::System::User');

    my %Params     = %Param;
    my $IndexName  = 'CustomerUser';
    my $ObjectData = $Params{Objects}->{$IndexName};

    my $Loaded = $SearchChildObject->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${IndexName}",
    );

    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${IndexName}");

    # check/set valid result type
    my $ValidResultType = $SearchChildObject->ValidResultType(
        SupportedResultTypes => $IndexQueryObject->{IndexSupportedResultTypes},
        ResultType           => $Param{ResultType},
    );

    # do not build query for objects
    # with not valid result type
    return if !$ValidResultType;

    my $OrderBy = $ObjectData->{OrderBy};
    my $Limit   = $ObjectData->{Limit};
    my $Fields  = $ObjectData->{Fields};

    my $SortBy = $Self->SortParamApply(
        %Param,
        SortBy     => $ObjectData->{SortBy},
        ResultType => $ValidResultType,
        OrderBy    => $OrderBy,
    );

    return $Self->ExecuteSearch(
        %Param,
        Limit => $Limit
            || $IndexQueryObject->{IndexDefaultSearchLimit},    # default limit or override with limit from param
        Fields        => $Fields,
        QueryParams   => $Param{QueryParams},
        SortBy        => $SortBy,
        RealIndexName => $Self->{Config}->{IndexRealName},
        ResultType    => $ValidResultType,
    );
}

sub ObjectIndexAdd() {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Self->{ActiveDBBackend}->{ValidBackend} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Valid backend for Elasticsearch engine was not found!' . "\n" .
                'Configure Elasticsearch module for CustomerUser backend and reindex data or disable CustomerUser index.',
        );
        return;
    }

    return $Self->SUPER::ObjectIndexAdd(
        %Param,
    );
}

sub ObjectIndexSet() {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Self->{ActiveDBBackend}->{ValidBackend} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Valid backend for Elasticsearch engine was not found!' . "\n" .
                'Configure Elasticsearch module for CustomerUser backend and reindex data or disable CustomerUser index.',
        );
        return;
    }

    return $Self->SUPER::ObjectIndexSet(
        %Param,
    );
}

sub ObjectIndexUpdate() {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Self->{ActiveDBBackend}->{ValidBackend} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Valid backend for Elasticsearch engine was not found!' . "\n" .
                'Configure Elasticsearch module for CustomerUser backend and reindex data or disable CustomerUser index.',
        );
        return;
    }

    # custom handling of update
    if ( IsHashRefWithData( $Param{CustomFunction} ) ) {
        return $Self->CustomFunction(%Param);
    }
    else {
        return $Self->SUPER::ObjectIndexUpdate(
            %Param,
        );
    }
}

sub ObjectIndexRemove() {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Self->{ActiveDBBackend}->{ValidBackend} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Valid backend for Elasticsearch engine was not found!' . "\n" .
                'Configure Elasticsearch module for CustomerUser backend and reindex data or disable CustomerUser index.',
        );
        return;
    }

    return if !$Self->{ActiveDBBackend}->{ValidBackend};

    return $Self->SUPER::ObjectIndexRemove(
        %Param,
    );
}

=head2 ExecuteSearch()

perform actual search

    my $Result = $SearchCustomerUserESObject->ExecuteSearch(
        %Param,
        Limit          => $Limit,
        Fields         => $Fields,
        QueryParams    => $Param{QueryParams},
        SortBy         => $SortBy,
        OrderBy        => $OrderBy,
        RealIndexName  => $Self->{Config}->{IndexRealName},
        ResultType     => $ValidResultType,
    );

=cut

sub ExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    if ( $Param{UseSQLSearch} || $SearchObject->{Fallback} || !$Self->{ActiveDBBackend}->{ValidBackend} ) {
        return $Self->FallbackExecuteSearch(%Param);
    }

    my $OperatorModule   = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");
    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");

    my $QueryParams = $Param{QueryParams};

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams => $QueryParams,
        QueryFor    => 'Engine',
        Strict      => 1,
    );

    return $Self->SearchEmptyResponse(%Param)
        if ref $SearchParams eq 'HASH' && $SearchParams->{Error};

    my $SegregatedQueryParams = {
        CustomerUser => $SearchParams,
    };

    my $Fields                    = $Param{Fields}                       || {};
    my $CustomerUserFields        = $Fields->{CustomerUser}              || {};
    my $CustomerUserDynamicFields = $Fields->{CustomerUser_DynamicField} || {};

    my %CustomerUserFields = ( %{$CustomerUserFields}, %{$CustomerUserDynamicFields} );

    # build standard CustomerUser query
    my $Query = $Param{MappingObject}->Search(
        %Param,
        Fields      => \%CustomerUserFields,
        QueryParams => $SegregatedQueryParams->{CustomerUser},
        Object      => $Self->{Config}->{IndexName},
        _Source     => 1,
    );

    # execute query
    my $Response = $Param{EngineObject}->QueryExecute(
        Query         => $Query,
        Operation     => 'Search',
        ConnectObject => $Param{ConnectObject},
        Config        => $Param{GlobalConfig},
        Silent        => $Param{Silent},
    );

    # format query
    my $FormattedResult = $SearchObject->SearchFormat(
        %Param,
        Fields     => \%CustomerUserFields,
        Result     => $Response,
        IndexName  => 'CustomerUser',
        ResultType => $Param{ResultType} || 'ARRAY',
        QueryData  => {
            Query => $Query
        },
    );

    return $FormattedResult;

}

=head2 FallbackExecuteSearch()

execute full fallback for searching CustomerUsers

notice: fall-back does not support searching by dynamic fields yet

    my $FunctionResult = $SearchCustomerUserESObject->FallbackExecuteSearch(
        %Params,
    );

=cut

sub FallbackExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    # TODO: support for fallback
    return $Self->SearchEmptyResponse(%Param)
        if !$Param{ResultType} || ( $Param{ResultType} && $Param{ResultType} ne 'COUNT' ) && !$Param{Force};

    my $Result = {
        CustomerUser => $Self->Fallback( %Param, Fields => $Param{Fields}->{CustomerUser} ) // []
    };

    # format reponse
    my $FormattedResult = $SearchObject->SearchFormat(
        Result     => $Result,
        Config     => $Param{GlobalConfig},
        IndexName  => $Self->{Config}->{IndexName},
        ResultType => $Param{ResultType} || 'ARRAY',
        Fallback   => 1,
        Silent     => $Param{Silent},
        Fields     => $Param{Fields}->{CustomerUser},
    );

    return $FormattedResult || { CustomerUser => [] };
}

=head2 SQLObjectSearch()

search in sql database for objects index related

    my $Result = $SearchCustomerUserESObject->SQLObjectSearch(
        QueryParams => {
            CustomerUserID => 1,
        },
        Fields      => ['CustomerUserID', 'SLAID'] # optional, returns all
                                             # fields if not specified
        SortBy      => $IdentifierSQL,
        OrderBy     => "Down",  # possible: "Down", "Up",
        ResultType  => $ResultType,
        Limit       => 10,
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    if ( !$Self->{ActiveDBBackend} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Active customer user Elasticsearch backend was not found!"
        );
        return {
            Success => 0,
            Data    => [],
        };
    }

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    my $QueryParams = $Param{QueryParams};
    my $Fields      = $Param{Fields};

    # perform default sql object search
    my $SQLSearchResult = $Self->SUPER::SQLObjectSearch(
        %Param,
        QueryParams => $QueryParams,
        Fields      => $Fields,
    );

    return $SQLSearchResult if !$SQLSearchResult->{Success};
    return $SQLSearchResult if !IsArrayRefWithData( $SQLSearchResult->{Data} );

    # get all dynamic fields for the object type CustomerUser
    my $CustomerUserDynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'CustomerUser'
    );

    if ( !$Param{IgnoreDynamicFields} ) {
        CUSTOMER_USER:
        for my $CustomerUser ( @{ $SQLSearchResult->{Data} } ) {
            my $ObjectMapping = $DynamicFieldObject->ObjectMappingGet(
                ObjectName => $CustomerUser->{UserLogin},
                ObjectType => 'CustomerUser',
            );

            my $ObjectID;
            if ( IsHashRefWithData($ObjectMapping) && keys %{$ObjectMapping} == 1 ) {
                for my $ObjectMapID ( values %{$ObjectMapping} ) {
                    $ObjectID = $ObjectMapID;
                }
            }

            next CUSTOMER_USER if !$ObjectID;

            DYNAMICFIELDCONFIG:
            for my $DynamicFieldConfig ( @{$CustomerUserDynamicFieldList} ) {

                # get the current value for each dynamic field
                my $Value = $DynamicFieldBackendObject->ValueGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $ObjectID,
                );

                # set the dynamic field name and value into the CustomerUser hash
                # only if value is defined
                next DYNAMICFIELDCONFIG if !defined $Value;
                $CustomerUser->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
            }
        }
    }

    return $SQLSearchResult;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchCustomerUserESObject->ValidFieldsPrepare(
        Fields      => $Fields, # optional
        Object      => $ObjectName,
        QueryParams => $QueryParams,
    );

=cut

sub ValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Object)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return ();
    }

    my $IndexSearchObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Object}");
    my $SearchQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Object}");
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

    my $Fields         = $IndexSearchObject->{Fields};
    my $ExternalFields = $IndexSearchObject->{ExternalFields} // {};
    my %ValidFields;

    # when no fields are specified use all standard fields
    # (without dynamic fields)
    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        my %ValidFieldsPrepared = $SearchChildObject->_PostValidFieldsPrepare(
            ValidFields => { %{$Fields}, %{$ExternalFields} },
            QueryParams => $Param{QueryParams},
        );

        $ValidFields{CustomerUser} = \%ValidFieldsPrepared;

        return %ValidFields;
    }

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    FIELDS:
    for my $ParamField ( @{ $Param{Fields} } ) {

        # get information about field types if field
        # matches specified regexp
        if ( $ParamField =~ m{\A(?:(CustomerUser)_DynamicField_(.+))} ) {

            my $DynamicFieldName = $2;
            my $ObjectType       = $1;

            if ( $DynamicFieldName eq '*' ) {

                # get all dynamic fields for object type "CustomerUser"
                my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
                    ObjectType => $ObjectType,
                );

                DYNAMICFIELD:
                for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
                    my $Info = $SearchQueryObject->_QueryDynamicFieldInfoGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next FIELDS if !$Info->{ColumnName};
                    $ValidFields{ $ObjectType . '_DynamicField' }->{ $Info->{ColumnName} } = $Info;
                }
            }
            else {
                # get single dynamic field config
                my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                    Name => $DynamicFieldName,
                );

                next FIELDS if $ObjectType ne $DynamicFieldConfig->{ObjectType};

                if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {
                    my $Info = $SearchQueryObject->_QueryDynamicFieldInfoGet(
                        ObjectType         => $ObjectType,
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next FIELDS if !$Info->{ColumnName};
                    $ValidFields{ $ObjectType . '_DynamicField' }->{ $Info->{ColumnName} } = $Info;
                }
            }
        }

        # apply "CustomerUser" fields
        elsif ( $ParamField =~ m{\ACustomerUser_(.+)\z} ) {
            my $CustomerUserField = $1;

            # get single "CustomerUser" field
            if ( $Fields->{$CustomerUserField} ) {
                $ValidFields{$CustomerUserField} = $Fields->{$CustomerUserField};
            }

            # get single field from external fields
            elsif ( $ExternalFields->{$CustomerUserField} ) {
                $ValidFields{$CustomerUserField} = $ExternalFields->{$CustomerUserField};
            }

            # get all "CustomerUser" fields
            elsif ( $CustomerUserField eq '*' ) {
                my $CustomerUserFields = $ValidFields{CustomerUser} // {};
                %ValidFields = ( %{$Fields}, %{$ExternalFields}, %{$CustomerUserFields} );
            }
        }
    }

    my %ValidFieldsPrepared = $SearchChildObject->_PostValidFieldsPrepare(
        ValidFields => \%ValidFields,
        QueryParams => $Param{QueryParams},
    );

    $ValidFields{CustomerUser} = \%ValidFieldsPrepared;

    return %ValidFields;
}

=head2 ObjectListIDs()

return all sql data of object ids

    my $ResultIDs = $SearchCustomerUserObject->ObjectListIDs();

=cut

sub ObjectListIDs {
    my ( $Self, %Param ) = @_;

    my $IndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Self->{Config}->{IndexName}");
    my $Identifier  = $IndexObject->{Config}->{Identifier};

    # search for all objects
    my $SQLSearchResult = $IndexObject->SQLObjectSearch(
        QueryParams         => $Param{QueryParams} || {},
        Fields              => [$Identifier],
        OrderBy             => $Param{OrderBy},
        SortBy              => $Param{SortBy} // $Identifier,
        ResultType          => $Param{ResultType} || 'ARRAY_SIMPLE',
        Limit               => $Param{Limit},
        Offset              => $Param{Offset},
        IgnoreDynamicFields => 1,
    );

    my @Result;
    if ( $SQLSearchResult->{Success} ) {
        return $SQLSearchResult->{Data};
    }

    return \@Result;
}

=head2 ObjectIndexUpdateDFChanged()

update customer user that contains specified dynamic field

    my $Success = $SearchCustomerUserObject->ObjectIndexUpdateDFChanged(
        ConnectObject => $ConnectObject,
        EngineObject => $EngineObject,
        MappingObject => $MappingObject,
        Params => {
            DynamicField => {
                ObjectType => $ObjectType,
                Name       => $OldDFName,
                NewName    => $Param{Data}->{NewData}->{Name},
                Event      => 'NameChange', # also possible: 'Remove'
            }
        }
    );

=cut

sub ObjectIndexUpdateDFChanged {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed (qw( ConnectObject EngineObject MappingObject)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !$Param{Params}->{DynamicField} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need 'DynamicField' inside Params hash!"
        );
        return;
    }

    NEEDED:
    for my $Needed (qw(ObjectType Name Event)) {

        next NEEDED if defined $Param{Params}->{DynamicField}->{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed inside Params->{DynamicField} hash!",
        );
        return;
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");
    my %Body;

    my $DynamicFieldType  = $Param{Params}->{DynamicField}->{ObjectType};
    my $DynamicFieldName  = $Param{Params}->{DynamicField}->{Name};
    my $DynamicFieldEvent = $Param{Params}->{DynamicField}->{Event};

    return if $DynamicFieldType ne 'CustomerUser';
    my $NewName = $Param{Params}->{DynamicField}->{NewName} || '';

    # build body
    %Body = (
        query => {
            bool => {
                should => [
                    {
                        exists =>
                            {
                            field => "DynamicField_$DynamicFieldName"
                            },
                    },
                    {
                        exists =>
                            {
                            field => "DynamicField_"
                                . $NewName,
                            }
                    }
                ]
            }
        }
    );
    my $Source;

    # remove dynamic field
    if ( $DynamicFieldEvent eq 'Remove' ) {
        $Source = "
            ctx._source.remove('DynamicField_$DynamicFieldName');
        ";
    }

    # change name of dynamic field
    elsif ( $DynamicFieldEvent eq 'NameChange' ) {
        if ( !$Param{Params}->{DynamicField}->{NewName} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter 'NewName' is needed inside Params->{DynamicField} hash!",
            );
            return;
        }

        my $NewDFName = $Param{Params}->{DynamicField}->{NewName};
        my $OldDFName = $DynamicFieldName;

        $Source = "
            if(ctx._source.DynamicField_$OldDFName != null){
                if(ctx._source.DynamicField_$NewDFName == null){
                    ctx._source.put('DynamicField_$NewDFName', ctx._source.DynamicField_$OldDFName);
                }
                ctx._source.remove('DynamicField_$OldDFName');
            }
        ";
    }
    else {
        return;
    }

    my $Query = {
        Method => 'POST',
        Path   => "$Self->{Config}->{IndexRealName}/_update_by_query",
        Body   => {
            %Body,
            script => {
                source => $Source,
            },
        },
        QS => {
            wait_for_completion => 'true',
            timeout             => '30s',
            refresh             => 'true',
        }
    };

    my $Response = $Param{EngineObject}->QueryExecute(
        Operation     => 'Generic',
        Query         => $Query,
        ConnectObject => $Param{ConnectObject},
    );

    return $Param{MappingObject}->ResponseIsSuccess(
        Response => $Response,
    );
}

1;
