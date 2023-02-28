# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## nofilter(TidyAll::Plugin::Znuny4OTRS::Perl::ObjectManagerDirectCall)

package Kernel::System::Search::Object::Engine::ES::Ticket;

use strict;
use warnings;
use MIME::Base64;
use POSIX qw/ceil/;

use parent qw( Kernel::System::Search::Object::Default::Ticket );
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Search::Object',
    'Kernel::System::Log',
    'Kernel::System::Search',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Group',
    'Kernel::System::Queue',
    'Kernel::System::User',
    'Kernel::System::Search::Object::Query::Ticket',
    'Kernel::System::DB',
    'Kernel::System::Search::Object::Default::Article',
    'Kernel::Config',
    'Kernel::System::Ticket::Article',
    'Kernel::System::Search::Object::Operators',
    'Kernel::System::Encode',
    'Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment',
);

=head1 NAME

Kernel::System::Search::Object::Engine::ES::Ticket - common base backend functions for specified object

=head1 DESCRIPTION

This module defines schema and rules for specified object to be used
for fallback or separate engine.

=head1 PUBLIC INTERFACE

=head2 new()

Don' t use the constructor directly, use the ObjectManager instead :

        my $SearchTicketESObject = $Kernel::OM->Get('Kernel::System::Search::Object::Engine::ES::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Module} = 'Kernel::System::Search::Object::Engine::ES::Ticket';

    # specify base config for index
    $Self->{Config} = {
        IndexRealName => 'ticket',      # index name on the engine/sql side
        IndexName     => 'Ticket',      # index name on the api side
        Identifier    => 'TicketID',    # column name that represents object id in the field mapping
    };

    # define schema for data
    my $FieldMapping = {
        TicketID => {
            ColumnName => 'id',
            Type       => 'Integer'
        },
        TicketNumber => {
            ColumnName => 'tn',
            Type       => 'String'
        },
        Title => {
            ColumnName => 'title',
            Type       => 'String'
        },
        QueueID => {
            ColumnName => 'queue_id',
            Type       => 'Integer'
        },
        LockID => {
            ColumnName => 'ticket_lock_id',
            Type       => 'Integer'
        },
        TypeID => {
            ColumnName => 'type_id',
            Type       => 'Integer'
        },
        ServiceID => {
            ColumnName => 'service_id',
            Type       => 'Integer'
        },
        SLAID => {
            ColumnName => 'sla_id',
            Type       => 'Integer'
        },
        OwnerID => {
            ColumnName => 'user_id',
            Type       => 'Integer'
        },
        ResponsibleID => {
            ColumnName => 'responsible_user_id',
            Type       => 'Integer'
        },
        PriorityID => {
            ColumnName => 'ticket_priority_id',
            Type       => 'Integer'
        },
        StateID => {
            ColumnName => 'ticket_state_id',
            Type       => 'Integer'
        },
        CustomerID => {
            ColumnName => 'customer_id',
            Type       => 'String'
        },
        CustomerUserID => {
            ColumnName => 'customer_user_id',
            Type       => 'String'
        },
        UnlockTimeout => {
            ColumnName => 'timeout',
            Type       => 'Integer'
        },
        EscalationTime => {
            ColumnName => 'escalation_time',
            Type       => 'Integer'
        },
        EscalationUpdateTime => {
            ColumnName => 'escalation_update_time',
            Type       => 'Integer'
        },
        EscalationResponseTime => {
            ColumnName => 'escalation_response_time',
            Type       => 'Integer'
        },
        EscalationSolutionTime => {
            ColumnName => 'escalation_solution_time',
            Type       => 'Integer'
        },
        ArchiveFlag => {
            ColumnName => 'archive_flag',
            Type       => 'Integer'
        },
        Created => {
            ColumnName => 'create_time',
            Type       => 'Date'
        },
        CreateBy => {
            ColumnName => 'create_by',
            Type       => 'Integer'
        },
        Changed => {
            ColumnName => 'change_time',
            Type       => 'Date'
        },
        ChangeBy => {
            ColumnName => 'change_by',
            Type       => 'Integer'
        },
    };

    $Self->{ExternalFields} = {
        GroupID => {
            ColumnName => 'group_id',
            Type       => 'Integer',
            Alias      => 0,
        },
    };

    # define searchable fields
    # that can be used as query parameters
    # for either indexing or searching
    $Self->{SearchableFields} = {
        SQL    => '*',
        Engine => '*',
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

    my $Result = $SearchTicketESObject->Search(
        TicketID => $Param{TicketID},
        Objects       => ['Ticket'],
        Counter       => $Counter,
        MappingObject => $MappingObject},
        EngineObject  => $EngineObject},
        ConnectObject => $ConnectObject},
        GlobalConfig  => $Config},
    );

On executing ticket search by Kernel::System::Search:
    my $Result = $Kernel::OM->Get('Kernel::System::Search')->Search(
        Objects => ["Ticket"],
        QueryParams => {
            # standard ticket fields
            TicketID => 1,
            TicketNumber => 2022101276000016,
            Title => 'some-title',
            QueueID => 1,
            LockID => 1,
            TypeID => 1,
            ServiceID => 1,
            SLAID => 1,
            OwnerID => 1,
            ResponsibleID => 1,
            PriorityID => 1,
            StateID => 1,
            CustomerID => '333',
            CustomerUserID => 'some-customer-user-id',
            UnlockTimeout => 0,
            EscalationTime => 0,
            EscalationUpdateTime => 0,
            EscalationResponseTime => 0,
            EscalationSolutionTime => 0,
            ArchiveFlag => 1,
            Created => "2022-08-17 13:13:23",
            CreateBy => 1,
            Changed => "2022-08-17 13:13:39",
            ChangeBy => 1,

            # ticket dynamic fields
            DynamicField_Text => 'TextValue',
            DynamicField_Multiselect => [1,2,3],

            # article fields (denormalized)
            Article_From => 'value',
            Article_To => 'value',
            Article_Cc => 'value',
            Article_Subject => 'value',
            Article_Body => 'value',
            Article_*OtherArticleDataMIMEValues* => 'value',
            Article_SenderTypeID => 'value',
            Article_CommunicationChannelID => 'value',
            Article_IsVisibleForCustomer => 1/0

            # article dynamic fields
            Article_DynamicField_Text => 'TextValue',
            Article_DynamicField_Multiselect => [1,2,3],

            # attachments
            Attachment_ContentAlternative => 'value',
            Attachment_ContentID          => 'value',
            Attachment_Disposition        => 'value',
            Attachment_ContentType        => 'value',
            Attachment_Filename           => 'value',
            Attachment_ID                 => 'value',

            # attachment ingest plugin field, use to search in attachment content as pdf, ppt, xls etc.
            Attachment_AttachmentContent => {
                Operator => 'FULLTEXT', Value => {
                    OperatorQuery => 'AND',
                    Text => 'value',
                }
            },

            # permission parameters
            # required either group id or UserID
            GroupID => [1,2,3],
            # when combined witch UserID, there is used "OR" match
            # meaning groups for specified user including groups from
            # "GroupID" will match tickets
            UserID => 1, # no operators support
            Permissions => 'ro' # no operators support, by default "ro" value will be used
                                # permissions for user, therefore should be combined with UserID param

            # additionally there is a possibility to pass names for fields below
            # always pass them in an array or scalar
            # can be combined with it's ID's alternative (will match
            # by "AND" operator as any other fields)
            # operators syntax is not supported on those fields
            Queue        => ['Misc', 'Junk'], # search by queue name
            SLA          => ['SLA5min'],
            SLAID        => [1],
            Lock         => ['Locked'],
            Type         => ['Unclassified', 'Classified'],
            Service      => ['PremiumService'],
            Owner        => ['root@localhost'],
            Responsible  => ['root@localhost'],
            Priority     => ['3 normal'],
            State        => ['open'],
            Customer     => ['customer123', 'customer12345'], # search by customer name
            CustomerUser => ['customeruser123', 'customeruser12345'], # same as CustomerUserID,
                                                                      # possible to use because of compatibility with
                                                                      # Ticket API
            ChangeByLogin => ['root@localhost'],
            CreateByLogin => ['root@localhost'],

            # fulltext parameter can be used to search by properties specified
            # in sysconfig "SearchEngine::ES::TicketSearchFields###Fulltext"
            Fulltext      => 'elasticsearch',
            #    OR
            Fulltext      => ['elasticsearch', 'kibana'],
            #    OR
            Fulltext      => {
                Text => ['elasticsearch', 'kibana'],
                QueryOperator => 'AND', # determine if all words from specified
                                        # value needs to match
                                        # optional, default: "AND"
                                        # possible: "OR" - only single word needs to match
                                        #           "AND" - all words needs to match
                                        # example: 'elasticsearch is super fast'
                                        # each of those are separate words, decide here if
                                        # all of them needs to be matched or only one
                StatementOperator => 'OR', # determine if all values from specified ones
                                           # in an array needs to match
                                           # optional, default: "OR"
                                           # possible: "OR" - single value from an array needs to match
                                           #           "AND" - all values from an array needs to match
                                           # use only when specifying multiple values to search by
                                           # example: ['elasticsearch is super fast', 'sql search is slower for fulltext search']
                                           # decide here if both of these values needs to matched or only one
            }
        },
        Fields => [['Ticket_TicketID', 'Ticket_TicketNumber']] # specify field from field mapping
            # to get:
            # - ticket fields (all): [['Ticket_*']]
            # - ticket field (specified): [['Ticket_TicketID', 'Ticket_Title']]
            # - ticket dynamic fields (all): [['Ticket_DynamicField_*']]
            # - ticket dynamic fields (specified): [['Ticket_DynamicField_multiselect', 'Ticket_DynamicField_dropdown']]
            # - ticket "GroupID" field (external field): [['Ticket_GroupID']]
            # - article fields (all): [['Article_*']]
            # - article field (specified): [['Article_Body']]
            # - article dynamic fields (all): [['Article_DynamicField_*']]
            # - article dynamic field (specified): [['Article_DynamicField_Body']]
            # - attachment (all standard fields + AttachmentContent): [['Attachment_*']]
            # - attachment (specified): [['Attachment_ContentID']]
    );

    Parameter "AdvancedSearchQuery" is not supported on this object.

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $UserObject        = $Kernel::OM->Get('Kernel::System::User');

    # copy standard param to avoid overwriting on standarization
    my %Params     = %Param;
    my $IndexName  = 'Ticket';
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
    );

    return $Self->ExecuteSearch(
        %Param,
        Limit => $Limit
            || $IndexQueryObject->{IndexDefaultSearchLimit},    # default limit or override with limit from param
        Fields        => $Fields,
        QueryParams   => $Param{QueryParams},
        SortBy        => $SortBy,
        OrderBy       => $OrderBy,
        RealIndexName => $Self->{Config}->{IndexRealName},
        ResultType    => $ValidResultType,
    );
}

=head2 ExecuteSearch()

perform actual search

    my $Result = $SearchTicketESObject->ExecuteSearch(
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
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    if (
        !$Param{NoPermissions}
        &&
        !$Param{QueryParams}->{UserID} &&
        !IsArrayRefWithData( $Param{QueryParams}->{GroupID} )
        )
    {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Either UserID or GroupID is required for ticket search!"
        );
        return $Self->SearchEmptyResponse(%Param);
    }

    if ( $Param{UseSQLSearch} || $SearchObject->{Fallback} ) {
        return $Self->FallbackExecuteSearch(%Param);
    }

    my $OperatorModule   = $Kernel::OM->Get("Kernel::System::Search::Object::Operators");
    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');

    my @QueryParamsKey = keys %{ $Param{QueryParams} };
    my $QueryParams    = $Param{QueryParams};

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams   => $QueryParams,
        NoPermissions => $Param{NoPermissions},
        QueryFor      => 'Engine',
    );

    return $Self->SearchEmptyResponse(%Param)
        if ref $SearchParams eq 'HASH' && $SearchParams->{Error};

    my $SegregatedQueryParams;

    # segregate search params
    for my $SearchParam ( sort keys %{$SearchParams} ) {
        if ( $SearchParam =~ m{^Article_DynamicField_(.+)} ) {
            $SegregatedQueryParams->{ArticleDynamicFields}->{$1} =
                $SearchParams->{$SearchParam};
        }
        elsif ( $SearchParam =~ m{^Article_(.+)} ) {
            $SegregatedQueryParams->{Articles}->{$1} =
                $SearchParams->{$SearchParam};
        }
        elsif ( $SearchParam =~ m{^Attachment_(.+)} ) {
            $SegregatedQueryParams->{Attachments}->{$1} =
                $SearchParams->{$SearchParam};
        }
        else {
            $SegregatedQueryParams->{Ticket}->{$SearchParam} = $SearchParams->{$SearchParam};
        }
    }

    my $Fields               = $Param{Fields}                  || {};
    my $TicketFields         = $Fields->{Ticket}               || {};
    my $TicketDynamicFields  = $Fields->{Ticket_DynamicField}  || {};
    my $ArticleFields        = $Fields->{Article}              || {};
    my $ArticleDynamicFields = $Fields->{Article_DynamicField} || {};
    my $AttachmentFields     = $Fields->{Attachment}           || {};

    my %TicketFields  = ( %{$TicketFields},  %{$TicketDynamicFields} );
    my %ArticleFields = ( %{$ArticleFields}, %{$ArticleDynamicFields} );
    my %AttachmentFields = %{$AttachmentFields};

    # build standard ticket query
    my $Query = $Param{MappingObject}->Search(
        %Param,
        Fields      => \%TicketFields,
        QueryParams => $SegregatedQueryParams->{Ticket},
        Object      => $Self->{Config}->{IndexName},
        _Source     => 1,
    );

    my $FulltextTicketQuery;
    my $FulltextArticleQuery;
    my $FulltextAttachmentQuery;

    # fulltext search
    if ( defined $QueryParams->{Fulltext} ) {
        my $FulltextValue;
        my $FulltextQueryOperator = 'AND';
        my $StatementOperator     = 'OR';
        if ( ref $QueryParams->{Fulltext} eq 'HASH' && $QueryParams->{Fulltext}->{Text} ) {
            $FulltextValue         = $QueryParams->{Fulltext}->{Text};
            $FulltextQueryOperator = $QueryParams->{Fulltext}->{QueryOperator}
                if $QueryParams->{Fulltext}->{QueryOperator};
            $StatementOperator = $QueryParams->{Fulltext}->{StatementOperator}
                if $QueryParams->{Fulltext}->{StatementOperator};
        }
        else {
            $FulltextValue = $QueryParams->{Fulltext};
        }
        if ( IsArrayRefWithData($FulltextValue) ) {
            $FulltextValue = join " $StatementOperator ", @{$FulltextValue};
        }
        if ( defined $FulltextValue )
        {
            my @FulltextQuery;

            # get fields to search
            my $ESTicketSearchFieldsConfig = $ConfigObject->Get('SearchEngine::ES::TicketSearchFields');
            my $FulltextSearchFields       = $ESTicketSearchFieldsConfig->{Fulltext};
            my @FulltextTicketFields       = @{ $FulltextSearchFields->{Ticket} };
            my @FulltextArticleFields      = map {"Articles.$_"} @{ $FulltextSearchFields->{Article} };
            my @FulltextAttachmentFields   = map {"Articles.Attachments.$_"} @{ $FulltextSearchFields->{Attachment} };

            # clean special characters
            $FulltextValue = $Param{EngineObject}->QueryStringReservedCharactersClean(
                String => $FulltextValue,
            );

            if ( scalar @FulltextTicketFields ) {
                $FulltextTicketQuery = {
                    query_string => {
                        fields           => \@FulltextTicketFields,
                        query            => "*$FulltextValue*",
                        default_operator => $FulltextQueryOperator,
                    },
                };
                push @FulltextQuery, $FulltextTicketQuery;
            }

            if ( scalar @FulltextArticleFields ) {
                $FulltextArticleQuery = {
                    query_string => {
                        fields           => \@FulltextArticleFields,
                        query            => "*$FulltextValue*",
                        default_operator => $FulltextQueryOperator,
                    },
                };
                push @FulltextQuery, {
                    nested => {
                        path => [
                            "Articles"
                        ],
                        query => $FulltextArticleQuery,
                    }
                };
            }

            if ( scalar @FulltextAttachmentFields ) {
                $FulltextAttachmentQuery = {
                    query_string => {
                        fields           => \@FulltextAttachmentFields,
                        query            => "*$FulltextValue*",
                        default_operator => $FulltextQueryOperator,
                    },
                };
                push @FulltextQuery, {
                    nested => {
                        path => [
                            "Articles.Attachments"
                        ],
                        query => $FulltextAttachmentQuery,
                    }
                };
            }

            if ( scalar @FulltextQuery ) {
                push @{ $Query->{Body}->{query}->{bool}->{must} }, {
                    bool => {
                        should => \@FulltextQuery,
                    }
                };
            }
        }
    }

    my $ArticleSearchParams              = $SegregatedQueryParams->{Articles};
    my $ArticleDynamicFieldsSearchParams = $SegregatedQueryParams->{ArticleDynamicFields};
    my $AttachmentSearchParams           = $SegregatedQueryParams->{Attachments};

    my $AttachmentNestedQuery = {
        nested => {
            path => 'Articles.Attachments',
        }
    };

    # check if there were any attachments passed
    # in "Fields" param, also check if result type ne COUNT to do not break query
    if ( keys %AttachmentFields && $Param{ResultType} ne "COUNT" ) {

        # prepare query part for children fields to retrieve
        for my $AttachmentField ( sort keys %AttachmentFields ) {
            push @{ $Query->{Body}->{_source} },
                'Articles.Attachments.' . $AttachmentField;
        }
    }

    # build and append attachment query if needed
    if ( IsHashRefWithData($AttachmentSearchParams) ) {
        ATTACHMENT:
        for my $AttachmentField ( sort keys %{$AttachmentSearchParams} ) {
            for my $OperatorData ( @{ $AttachmentSearchParams->{$AttachmentField}->{Query} } ) {
                my $OperatorValue           = $OperatorData->{Value};
                my $AttachmentFieldForQuery = 'Articles.Attachments.' . $AttachmentField;

                # build query
                my $Result = $OperatorModule->OperatorQueryGet(
                    Field      => $AttachmentFieldForQuery,
                    ReturnType => $OperatorData->{ReturnType},
                    Value      => $OperatorValue,
                    Operator   => $OperatorData->{Operator},
                    Object     => 'Ticket',
                );

                my $AttachmentQuery = $Result->{Query};

                # append query
                push @{ $AttachmentNestedQuery->{nested}->{query}->{bool}->{ $Result->{Section} } }, $AttachmentQuery;
            }
        }
    }

    my $NestedAttachmentQueryBuilt     = IsHashRefWithData( $AttachmentNestedQuery->{nested}->{query} ) ? 1 : 0;
    my $NestedAttachmentFieldsToSelect = keys %AttachmentFields                                         ? 1 : 0;

    my $ArticleNestedQuery = {
        nested => {
            path => 'Articles',
        }
    };

    # check if there were any article/article dynamic fields passed
    # in "Fields" param, also check if result type ne COUNT to do not break query
    if ( keys %ArticleFields && $Param{ResultType} ne "COUNT" ) {

        # prepare query part for children fields to retrieve
        for my $ArticleField ( sort keys %ArticleFields ) {
            push @{ $Query->{Body}->{_source} }, 'Articles.' . $ArticleField;
        }
    }

    # build and append article query if needed
    if ( IsHashRefWithData($ArticleSearchParams) ) {
        my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
        my %AllArticleFields    = ( %{ $SearchArticleObject->{Fields} }, %{ $SearchArticleObject->{ExternalFields} } );

        # check if field exists in the mapping
        for my $ArticleQueryParam ( sort keys %{$ArticleSearchParams} ) {
            delete $ArticleSearchParams->{$ArticleQueryParam} if ( !$AllArticleFields{$ArticleQueryParam} );
        }

        for my $ArticleField ( sort keys %{$ArticleSearchParams} ) {

            for my $OperatorData ( @{ $ArticleSearchParams->{$ArticleField}->{Query} } ) {
                my $OperatorValue        = $OperatorData->{Value};
                my $ArticleFieldForQuery = 'Articles.' . $ArticleField;

                # build query
                my $Result = $OperatorModule->OperatorQueryGet(
                    Field      => $ArticleFieldForQuery,
                    ReturnType => $OperatorData->{ReturnType},
                    Value      => $OperatorValue,
                    Operator   => $OperatorData->{Operator},
                    Object     => 'Ticket',
                );

                my $ArticleQuery = $Result->{Query};

                # append query
                push @{ $ArticleNestedQuery->{nested}->{query}->{bool}->{ $Result->{Section} } }, $ArticleQuery;
            }
        }
    }

    # build and append article dynamic fields query if needed
    if ( IsHashRefWithData($ArticleDynamicFieldsSearchParams) ) {
        my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        ARTICLEDYNAMICFIELDNAME:
        for my $ArticleDynamicFieldName ( sort keys %{$ArticleDynamicFieldsSearchParams} ) {

            my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                Name => $ArticleDynamicFieldName,
            );
            next ARTICLEDYNAMICFIELDNAME if !IsHashRefWithData($DynamicFieldConfig);

            my $FieldValueType = $DynamicFieldBackendObject->TemplateValueTypeGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                FieldType          => 'Edit',
            );

            my $ReturnType = $FieldValueType->{"DynamicField_$ArticleDynamicFieldName"} || 'SCALAR';

            for my $OperatorData ( @{ $ArticleDynamicFieldsSearchParams->{$ArticleDynamicFieldName}->{Query} } ) {

                my $OperatorValue        = $OperatorData->{Value};
                my $ArticleFieldForQuery = 'Articles.DynamicField_' . $ArticleDynamicFieldName;

                my $Result = $OperatorModule->OperatorQueryGet(
                    Field      => $ArticleFieldForQuery,
                    ReturnType => $ReturnType,
                    Value      => $OperatorValue,
                    Operator   => $OperatorData->{Operator},
                    Object     => 'Ticket',
                );

                my $ArticleQuery = $Result->{Query};

                push @{ $ArticleNestedQuery->{nested}->{query}->{bool}->{ $Result->{Section} } }, $ArticleQuery;
            }
        }
    }

    my $NestedQueryBuilt     = IsHashRefWithData( $ArticleNestedQuery->{nested}->{query} ) ? 1 : 0;
    my $NestedFieldsToSelect = keys %ArticleFields                                         ? 1 : 0;

    # apply nested article query if there is any valid query param
    # from either article or attachment
    if (
        $NestedQueryBuilt
        ||
        $NestedAttachmentQueryBuilt
        )
    {
        # apply in article query an attachment query if there is any
        # query param or field regarding attachment
        if ($NestedAttachmentQueryBuilt) {
            push @{ $ArticleNestedQuery->{nested}->{query}->{bool}->{must} }, $AttachmentNestedQuery;
        }

        push @{ $Query->{Body}->{query}->{bool}->{must} }, $ArticleNestedQuery;
    }

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
        Fields     => \%TicketFields,
        Result     => $Response,
        IndexName  => 'Ticket',
        ResultType => $Param{ResultType} || 'ARRAY',
        QueryData  => {
            Query => $Query
        },
    );
    return $FormattedResult;

}

=head2 FallbackExecuteSearch()

execute full fallback for searching tickets

notice: fall-back does not support searching by dynamic fields/articles yet

    my $FunctionResult = $SearchTicketESObject->FallbackExecuteSearch(
        %Params,
    );

=cut

sub FallbackExecuteSearch {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');

    # TODO support for fallback
    # disable fallback functionality
    return $Self->SearchEmptyResponse(%Param) if 1 == 1;

    my $Result = {
        Ticket => $Self->Fallback( %Param, Fields => $Param{Fields}->{Ticket} ) // []
    };

    # format reponse per index
    my $FormattedResult = $SearchObject->SearchFormat(
        Result     => $Result,
        Config     => $Param{GlobalConfig},
        IndexName  => $Self->{Config}->{IndexName},
        ResultType => $Param{ResultType} || 'ARRAY',
        Fallback   => 1,
        Silent     => $Param{Silent},
        Fields     => $Param{Fields}->{Ticket},
    );

    return $FormattedResult || { Ticket => [] };
}

sub ObjectIndexAdd() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function         => $Param{Function} || '_ObjectIndexAddAction',
        SetEmptyArticles => 1,
        RunPipeline      => 1,
        NoPermissions    => 1,
    );
}

sub ObjectIndexSet() {
    my ( $Self, %Param ) = @_;

    return $Self->ObjectIndexGeneric(
        %Param,
        Function         => '_ObjectIndexSetAction',
        SetEmptyArticles => 1,
        RunPipeline      => 1,
        NoPermissions    => 1,
    );
}

=head2 ObjectIndexUpdate()

update object to specified index

    my $Success = $SearchObject->ObjectIndexUpdate(
        Index    => 'Ticket',
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },

        # update tickets found from query params
        # specify at least one, do not combine "UpdateArticle" with "AddArticle"
        UpdateTicket  => 1, # base ticket properties with dynamic fields
        UpdateArticle => 5, # ticket nested articles with dynamic fields
                            # possible:
                            # - any article id: 1
                            # - array of article ids: [1,2,3,4,5]
                            # - every article: '*'

        AddArticle    => 1, # add nested articles with dynamic fields to ticket
                            # possible:
                            # - any article id: 1
                            # - array of article ids: [1,2,3,4,5]

        # perform custom handling
        CustomFunction => {
            Name => 'ObjectIndexUpdateGroupID',
            Params => {
                NewGroupID => $NewGroupID,
            }
        },
    );

=cut

sub ObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $Success   = 1;
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # update base ticket properties
    # or update specified ticket articles
    # or add specified ticket articles
    if ( $Param{UpdateTicket} || $Param{UpdateArticle} || $Param{AddArticle} ) {
        my $RunPipeline = $Param{UpdateArticle} || $Param{AddArticle} ? 1 : 0;

        # TODO: possible optimization to not get all of ticket base fields + dfs
        # on only article update action
        $Success = $Self->ObjectIndexGeneric(
            %Param,
            Function      => '_ObjectIndexUpdateAction',
            RunPipeline   => $RunPipeline,
            NoPermissions => 1,
        );
    }

    # custom handling of update
    if ( IsHashRefWithData( $Param{CustomFunction} ) ) {

        NEEDED:
        for my $Needed (qw(Name Params)) {

            next NEEDED if defined $Param{CustomFunction}->{$Needed};

            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter '$Needed' is needed in CustomFunction parameter!",
            );
            return;
        }

        my $FunctionName = $Param{CustomFunction}->{Name};

        my $CustomFunctionSuccess = $Self->$FunctionName(
            %Param,
            CustomFunction => undef,
            Params         => $Param{CustomFunction}->{Params},
            FunctionName   => $FunctionName,
        );

        $Success = $CustomFunctionSuccess if $Success;
    }

    return $Success;
}

=head2 ObjectIndexUpdateGroupID()

update tickets group id, do not use nested objects as query params

    my $Success = $SearchTicketESObject->ObjectIndexUpdateGroupID(
        Params => {
            NewGroupID => 1,
        }
        ConnectObject => $ConnectObject,
        EngineObject => $EngineObject,
        MappingObject => $MappingObject,
    );

=cut

sub ObjectIndexUpdateGroupID {
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

    if ( !$Param{Params}->{NewGroupID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need 'NewGroupID'!"
        );
        return;
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Self->{Config}->{IndexName}");

    # filter & prepare correct parameters
    my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
        QueryParams   => $Param{QueryParams},
        NoPermissions => 1,
        QueryFor      => 'Engine',
    );

    # build body
    my %Body = $Param{MappingObject}->_BuildQueryBodyFromParams(
        QueryParams => $SearchParams,
        Object      => $Self->{Config}->{IndexName},
    );

    my $Query = {
        Method => 'POST',
        Path   => "$Self->{Config}->{IndexRealName}/_update_by_query",
        Body   => {
            %Body,
            script => {
                params => {
                    value => $Param{Params}->{NewGroupID},
                },
                source => "ctx._source.GroupID = params.value",
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

=head2 ObjectIndexUpdateDFChanged()

update tickets that contains specified dynamic field

    my $Success = $SearchTicketESObject->ObjectIndexUpdateDFChanged(
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

    if ( $DynamicFieldType eq 'Ticket' ) {

        # filter & prepare correct parameters
        my $SearchParams = $IndexQueryObject->_QueryParamsPrepare(
            QueryParams   => $Param{QueryParams},
            NoPermissions => 1,
            QueryFor      => 'Engine',
        );

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
                                    . $Param{Params}->{DynamicField}->{NewName} || '',
                                }
                        }
                    ]
                }
            }
        );
    }
    else {
        # build body
        %Body = (
            query => {
                bool => {
                    must => [
                        {
                            nested => {
                                path  => 'Articles',
                                query => {
                                    bool => {
                                        should => [
                                            {
                                                exists =>
                                                    {
                                                    field => "Articles.DynamicField_$DynamicFieldName",
                                                    },
                                            },
                                            {
                                                exists =>
                                                    {
                                                    field => "Articles.DynamicField_"
                                                        . $Param{Params}->{DynamicField}->{NewName} || '',
                                                    }
                                            }
                                        ],
                                    }
                                }
                            }
                        }
                    ]
                }
            }
        );
    }

    my $Source;

    # remove dynamic field
    if ( $DynamicFieldEvent eq 'Remove' ) {
        if ( $DynamicFieldType eq 'Ticket' ) {
            $Source = "
                ctx._source.remove('DynamicField_$DynamicFieldName');
            ";
        }
        elsif ( $DynamicFieldType eq 'Article' ) {
            $Source = "
                ArrayList Articles = ctx._source.Articles;

                for(int i=0;i<Articles.size();i++){
                    if(Articles[i].DynamicField_$DynamicFieldName != null){
                        ctx._source.Articles[i].remove('DynamicField_$DynamicFieldName');
                    }
                }
            ";
        }
        else {
            return;
        }
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

        if ( $DynamicFieldType eq 'Ticket' ) {
            $Source = "
                if(ctx._source.DynamicField_$OldDFName != null){
                    if(ctx._source.DynamicField_$NewDFName == null){
                        ctx._source.put('DynamicField_$NewDFName', ctx._source.DynamicField_$OldDFName);
                    }
                    ctx._source.remove('DynamicField_$OldDFName');
                }
            ";
        }
        elsif ( $DynamicFieldType eq 'Article' ) {
            $Source = "
                ArrayList Articles = ctx._source.Articles;

                for(int i=0;i<Articles.size();i++){
                    if(Articles[i].DynamicField_$OldDFName != null){
                        if(Articles[i].DynamicField_$NewDFName == null){
                            ctx._source.Articles[i].put('DynamicField_$NewDFName', ctx._source.Articles[i].DynamicField_$OldDFName);
                        }
                        ctx._source.Articles[i].remove('DynamicField_$OldDFName');
                    }
                }
            ";
        }
        else {
            return;
        }
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

=head2 ObjectIndexGeneric()

search for tickets with restrictions, then perform specified operation

    my $Success = $SearchTicketESObject->ObjectIndexGeneric(
        Index    => 'Ticket',
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },

        Function => 'FunctionName' # function callback name
                                   # to which the object data
                                   # will be sent
        NoPermissions => 1 # optional, skip permissions check
    );

=cut

sub ObjectIndexGeneric {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $Function     = $Param{Function};

    return if !$Function;
    return if !$Self->_BaseCheckIndexOperation(%Param);

    my $Identifier = $Self->{Config}->{Identifier};

    my $QueryParams = $Param{QueryParams} ? $Param{QueryParams} : {
        $Identifier => $Param{ObjectID},
    };

    my $DataCount;
    my $SQLDataIDs;

    # ticket id limit to process at once
    my $IDLimit = 100_00;

    # additional limit for single request
    my $ReindexationSettings = $ConfigObject->Get('SearchEngine::Reindexation')->{Settings};
    my $ReindexationStep     = $ReindexationSettings->{ReindexationStep} // 10;

    # success is hard to identify for that many objects
    # simply return 1 when 100% of data will execute queries
    # correctly, otherwise return 0
    my $Success                = 1;
    my $TicketOffsetMultiplier = 0;

    do {
        my $TicketOffset = $TicketOffsetMultiplier++ * $IDLimit;

        $SQLDataIDs = $Self->ObjectListIDs(
            QueryParams => $QueryParams,
            Fields      => [$Identifier],
            ResultType  => 'ARRAY',
            Limit       => $IDLimit,
            Offset      => $TicketOffset,
        );

        $DataCount = scalar @{$SQLDataIDs};

        if ($DataCount) {

            # no need to apply object count restrictions
            if ( $DataCount <= $ReindexationStep ) {
                my $SQLSearchResult = $Self->SQLObjectSearch(
                    %Param,
                    QueryParams => {
                        $Identifier => $SQLDataIDs,
                    },
                    ResultType       => $Param{SQLSearchResultType} || 'ARRAY',
                    IgnoreArticles   => 1,
                    NoPermissions    => $Param{NoPermissions},
                    SetEmptyArticles => $Param{SetEmptyArticles},
                );

                my $SuccessLocal = $Self->$Function(
                    %Param,
                    DataToIndex => $SQLSearchResult,
                    TicketIDs   => $SQLDataIDs,
                );

                $Success = $SuccessLocal if $Success && !$SuccessLocal;
            }
            else {
                # restrict data size
                my $IterationCount = ceil( $DataCount / $ReindexationStep );

                # index data in parts
                for my $OffsetMultiplier ( 0 .. $IterationCount - 1 ) {
                    my $Offset = $OffsetMultiplier * $ReindexationStep;

                    my $SQLSearchResult = $Self->SQLObjectSearch(
                        %Param,
                        QueryParams => {
                            $Identifier => $SQLDataIDs,
                        },
                        ResultType       => $Param{SQLSearchResultType} || 'ARRAY',
                        IgnoreArticles   => 1,
                        Offset           => $Offset,
                        Limit            => $ReindexationStep,
                        NoPermissions    => $Param{NoPermissions},
                        SetEmptyArticles => $Param{SetEmptyArticles},
                    );

                    my @ObjectDataIDsToProcess = @{$SQLDataIDs}[ $Offset .. ( $Offset + $ReindexationStep - 1 ) ];

                    my $PartSuccess = $Self->$Function(
                        %Param,
                        DataToIndex => $SQLSearchResult,
                        TicketIDs   => \@ObjectDataIDsToProcess,
                    );

                    $Success = $PartSuccess if $Success && !$PartSuccess;
                }
            }

            # run pipeline if needed
            if ( $Param{RunPipeline} ) {
                $SearchObject->IndexRefresh(
                    Index => 'Ticket',
                );

                # run attachment pipeline after indexation
                my $Query = {
                    Method => 'POST',
                    Path   => "$Self->{Config}->{IndexRealName}/_update_by_query",
                    Body   => {
                        query => {
                            terms => {
                                TicketID => $SQLDataIDs,
                            },
                        },
                    },
                    QS => {
                        pipeline => 'attachment_nested',

                        # pipeline can be timed out on very large data
                        # to prevent it make a task inside
                        # elasticsearch
                        # to be uncommented if the problem will occur
                        # wait_for_completion => 'false', # <- uncomment this line
                    },
                };

                $Param{EngineObject}->QueryExecute(
                    Operation     => 'Generic',
                    Query         => $Query,
                    ConnectObject => $Param{ConnectObject},
                );
            }
        }
    } while ( $DataCount == $IDLimit );

    return $Success;
}

=head2 ObjectIndexArticle()

update nested article data on ticket index

    my $Result = $SearchTicketESObject->ObjectIndexArticle(
        ArticleData => $Param{ArticleData},
        Action => 'UpdateArticle', # also possible: 'AddArticle'
    );

=cut

sub ObjectIndexArticle {
    my ( $Self, %Param ) = @_;

    my $SearchChildObject         = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $ArticleObject             = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $EncodeObject              = $Kernel::OM->Get('Kernel::System::Encode');

    my $ArticleData = $Param{ArticleData};

    my $IndexIsValid = $SearchChildObject->IndexIsValid(
        IndexName => 'Ticket',
    );

    return if !$IndexIsValid;
    return if !$ArticleData->{Success};
    return if !IsArrayRefWithData( $ArticleData->{Data} );

    # check all configured article dynamic fields
    my $ArticleDynamicFields = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => 'Article',
    );

    my %ArticlesToIndex;
    my %AttachmentsToIndex;
    my @AllAttachments;

    my $QuerySource =
        "
ArrayList ArticlesToIndex = params.Articles;
ArrayList Articles = ctx._source.Articles;
";

    $QuerySource .= $Param{Action} eq 'UpdateArticle'
        ?

        "
for(int i=0;i<ArticlesToIndex.size();i++){
    for(int j=0;j<Articles.size();j++){
        if(Articles[j].ArticleID == ArticlesToIndex[i].ArticleID){
            ctx._source.Articles[j] = ArticlesToIndex[i];
            break;
        }
    }
}
"
        :

        # add article
        "
for(int i=0;i<ArticlesToIndex.size();i++){
    ctx._source.Articles.add(ArticlesToIndex[i]);
}
";

    $QuerySource .=
        "
ctx._source.AttachmentStorageClearTemp = params.AttachmentStorageClearTemp;
ctx._source.AttachmentStorageTemp = params.AttachmentStorageTemp;
";

    my $Success = 1;

    for my $Article ( @{ $ArticleData->{Data} } ) {

        # add article dynamic fields
        DYNAMICFIELDCONFIG:
        for my $DynamicFieldConfig ( @{$ArticleDynamicFields} ) {

            # get the current value for each dynamic field
            my $Value = $DynamicFieldBackendObject->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Article->{ArticleID},
            );

            $Article->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
        }

        my %Index = $ArticleObject->ArticleAttachmentIndex(
            TicketID         => $Article->{TicketID},
            ArticleID        => $Article->{ArticleID},
            ExcludePlainText => 1,
            ExcludeHTMLBody  => 1,
            ExcludeInline    => 1,
        );

        my @Attachments = ();

        for my $AttachmentID ( sort keys %Index ) {
            my %Attachment = $ArticleObject->ArticleAttachment(
                TicketID  => $Article->{TicketID},
                ArticleID => $Article->{ArticleID},
                FileID    => $AttachmentID,
            );

            push @Attachments, {
                ContentAlternative => $Attachment{ContentAlternative},
                ContentID          => $Attachment{ContentID},
                Disposition        => $Attachment{Disposition},
                ContentType        => $Attachment{ContentType},
                Filename           => $Attachment{Filename},
                ID                 => $AttachmentID,
                Content            => $Attachment{Content}
            };
        }

        # there is a need to store content as base64
        # as ingest pipeline needs it to create
        # readable attachment content
        ATTACHMENT:
        for my $Result (@Attachments) {
            if ( $Result->{Content} ) {
                $EncodeObject->EncodeOutput( \$Result->{Content} );
                $Result->{Content} = encode_base64( $Result->{Content}, '' );
            }
        }

        $Article->{Attachments} = \@Attachments;

        my $ArticleTemp = $Article;

        undef $Article;
        push @{ $ArticlesToIndex{ $ArticleTemp->{TicketID} } },    $ArticleTemp;
        push @{ $AttachmentsToIndex{ $ArticleTemp->{TicketID} } }, @{ $ArticleTemp->{Attachments} };

    }

    for my $TicketID ( sort keys %ArticlesToIndex ) {

        my $Query = {
            Method => 'POST',
            Path   => "$Self->{Config}->{IndexRealName}/_update/$TicketID",
            Body   => {
                script => {
                    source => $QuerySource,
                    params => {
                        Articles              => $ArticlesToIndex{$TicketID}    || [],
                        AttachmentStorageTemp => $AttachmentsToIndex{$TicketID} || [],
                        AttachmentStorageClearTemp => {},
                    }
                },
            },
        };

        my $Response = $Param{EngineObject}->QueryExecute(
            Operation     => 'Generic',
            Query         => $Query,
            ConnectObject => $Param{ConnectObject},
        );

        $Success = $Param{MappingObject}->ResponseIsSuccess(
            Response => $Response,
        ) if $Success;
    }

    return $Success;
}

=head2 ObjectIndexRemove()

remove object from specified index

    my $Success = $SearchObject->ObjectIndexRemove(
        Index => "Ticket",
        Refresh  => 1, # optional, define if indexed data needs
                       # to be refreshed for search call
                       # not refreshed data could not be found right after
                       # indexing (for example in elastic search engine)

        ObjectID => 1, # possible:
                       # - for single object indexing: 1
                       # - for multiple object indexing: [1,2,3]
        # or
        QueryParams => {
            TicketID => [1,2,3],
            SLAID => {
                Operator => 'IS NOT EMPTY'
            },
        },

        NoPermissions => 1 # optional, skip permissions check
    );

=cut

sub ObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    return $Self->SUPER::ObjectIndexRemove(
        %Param,
        NoPermissions => 1,
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

    my $QueryTicketObject = $Kernel::OM->Get('Kernel::System::Search::Object::Query::Ticket');

    my $MappingQuery = $QueryTicketObject->IndexMappingSet(
        MappingObject => $Param{MappingObject},
    );

    return if !IsHashRefWithData( $MappingQuery->{Body}->{properties} );

    my $DataTypes = $Param{MappingObject}->MappingDataTypesGet();

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    my $SearchArticleDataMIMEAttachmentObject
        = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment');
    my %ArticleFields = ( %{ $SearchArticleObject->{Fields} }, %{ $SearchArticleObject->{ExternalFields} } );
    my $ArticleDataMIMEAttachmentFields = $SearchArticleDataMIMEAttachmentObject->{Fields};

    # add nested type relation for articles
    if ( keys %ArticleFields ) {
        $MappingQuery->{Body}->{properties}->{Articles} = {
            type       => 'nested',
            properties => {
                Attachments => {
                    type => 'nested'
                }
            }
        };

        for my $ArticleFieldName ( sort keys %ArticleFields ) {
            $MappingQuery->{Body}->{properties}->{Articles}->{properties}->{$ArticleFieldName}
                = $DataTypes->{ $ArticleFields{$ArticleFieldName}->{Type} };
        }
        for my $ArticleFieldName ( sort keys %{$ArticleDataMIMEAttachmentFields} ) {

            $MappingQuery->{Body}->{properties}->{Articles}->{properties}->{Attachments}->{properties}
                ->{$ArticleFieldName} = $DataTypes->{ $ArticleDataMIMEAttachmentFields->{$ArticleFieldName}->{Type} };
        }
    }

    my $Response = $Param{EngineObject}->QueryExecute(
        %Param,
        Query         => $MappingQuery,
        Operation     => "IndexMappingSet",
        ConnectObject => $Param{ConnectObject},
    );

    return $Param{MappingObject}->IndexMappingSetFormat(
        %Param,
        Result => $Response,
        Config => $Param{Config},
    );
}

=head2 SQLObjectSearch()

TODO: add support for child "Field" parameters.

search in sql database for objects index related

    my $Result = $SearchTicketESObject->SQLObjectSearch(
        QueryParams => {
            TicketID => 1,
        },
        Fields      => ['TicketID', 'SLAID'] # optional, returns all
                                             # fields if not specified
        SortBy      => $IdentifierSQL,
        OrderBy     => "Down",  # possible: "Down", "Up",
        ResultType  => $ResultType,
        Limit       => 10,
    );

=cut

sub SQLObjectSearch {
    my ( $Self, %Param ) = @_;

    my $EncodeObject              = $Kernel::OM->Get('Kernel::System::Encode');
    my $GroupObject               = $Kernel::OM->Get('Kernel::System::Group');
    my $QueueObject               = $Kernel::OM->Get('Kernel::System::Queue');
    my $DBObject                  = $Kernel::OM->Get('Kernel::System::DB');
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $ArticleObject             = $Kernel::OM->Get('Kernel::System::Ticket::Article');
    my $SearchArticleObject       = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    my $SearchArticleDataMIMEAttachmentObject
        = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment');

    my $QueryParams = $Param{QueryParams};
    my $Fields      = $Param{Fields};
    my $GroupField;

    # fields passed as hash needs to be
    # converted into array due to further calculations
    if ( IsHashRefWithData($Fields) ) {
        my %Fields = %{ $Param{Fields} };
        undef $Fields;
        @{$Fields} = keys %{ $Param{Fields} };
    }
    elsif ( !$Fields || !IsArrayRefWithData($Fields) ) {

        # no fields specified will return response with standard fields
        # plus denormalized group id
        @{$Fields} = keys %{ $Self->{Fields} };
        $GroupField = 'GroupID';
    }

    my @GroupQueryParam;

    # delete groupid, userid, permissions from queryparams/fields
    # as those are not present in the ticket table
    # support them after standard sql search
    if ( IsArrayRefWithData( $QueryParams->{GroupID} ) ) {
        my $GroupIDs = delete $QueryParams->{GroupID};
        @GroupQueryParam = @{$GroupIDs};
    }
    elsif ( $QueryParams->{GroupID} ) {
        delete $QueryParams->{GroupID};
    }
    my $UserIDQueryParam      = delete $QueryParams->{UserID};
    my $PermissionsQueryParam = delete $QueryParams->{Permissions};

    if ( !$GroupField ) {
        FIELDS:
        for ( my $i = 0; $i < scalar @{$Fields}; $i++ ) {
            if ( $Fields->[$i] eq 'GroupID' ) {
                $GroupField = delete $Fields->[$i];
                @{$Fields} = grep {$_} @{$Fields};
                last FIELDS;
            }
        }
    }

    # perform default sql object search
    my $SQLSearchResult = $Self->SUPER::SQLObjectSearch(
        %Param,
        QueryParams => $QueryParams,
        Fields      => $Fields,
    );

    return $SQLSearchResult if !$SQLSearchResult->{Success};
    return $SQLSearchResult if !IsArrayRefWithData( $SQLSearchResult->{Data} );

    if ( !$Param{IgnoreDynamicFields} || !$Param{IgnoreArticles} ) {

        # get all dynamic fields for the object type Ticket
        my $TicketDynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
            ObjectType => 'Ticket'
        );

        # check all configured article dynamic fields
        my $ArticleDynamicFields = $DynamicFieldObject->DynamicFieldListGet(
            ObjectType => 'Article',
        );

        TICKET:
        for my $Ticket ( @{ $SQLSearchResult->{Data} } ) {

            if ( !$Param{IgnoreAttachmentsTemp} ) {
                $Ticket->{AttachmentStorageTemp} = [];
            }

            if ( !$Param{IgnoreDynamicFields} ) {
                DYNAMICFIELDCONFIG:
                for my $DynamicFieldConfig ( @{$TicketDynamicFieldList} ) {

                    # get the current value for each dynamic field
                    my $Value = $DynamicFieldBackendObject->ValueGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        ObjectID           => $Ticket->{TicketID},
                    );

                    $Ticket->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
                }
            }

            if ( !$Param{IgnoreArticles} ) {

                # search articles for specified ticket id
                my $Articles = $SearchArticleObject->SQLObjectSearch(
                    QueryParams => {
                        TicketID => $Ticket->{TicketID},
                    }
                );

                if ( $Articles->{Success} && IsArrayRefWithData( $Articles->{Data} ) ) {
                    for my $Article ( @{ $Articles->{Data} } ) {

                        # add article dynamic fields
                        DYNAMICFIELDCONFIG:
                        for my $DynamicFieldConfig ( @{$ArticleDynamicFields} ) {

                            # get the current value for each dynamic field
                            my $Value = $DynamicFieldBackendObject->ValueGet(
                                DynamicFieldConfig => $DynamicFieldConfig,
                                ObjectID           => $Article->{ArticleID},
                            );

                            $Article->{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $Value;
                        }

                        my %Index = $ArticleObject->ArticleAttachmentIndex(
                            TicketID         => $Ticket->{TicketID},
                            ArticleID        => $Article->{ArticleID},
                            ExcludePlainText => 1,
                            ExcludeHTMLBody  => 1,
                            ExcludeInline    => 1,
                        );

                        my @Attachments = ();

                        for my $AttachmentID ( sort keys %Index ) {
                            my %Attachment = $ArticleObject->ArticleAttachment(
                                TicketID  => $Ticket->{TicketID},
                                ArticleID => $Article->{ArticleID},
                                FileID    => $AttachmentID,
                            );

                            push @Attachments, {
                                ContentAlternative => $Attachment{ContentAlternative},
                                ContentID          => $Attachment{ContentID},
                                Disposition        => $Attachment{Disposition},
                                ContentType        => $Attachment{ContentType},
                                Filename           => $Attachment{Filename},
                                ID                 => $AttachmentID,
                                Content            => $Attachment{Content}
                            };
                        }

                        # there is need to store content as base64
                        ATTACHMENT:
                        for my $Result (@Attachments) {
                            if ( $Result->{Content} ) {
                                $EncodeObject->EncodeOutput( \$Result->{Content} );
                                $Result->{Content} = encode_base64( $Result->{Content}, '' );
                            }
                        }

                        $Article->{Attachments} = \@Attachments;

                        if ( !$Param{IgnoreAttachmentsTemp} ) {
                            push @{ $Ticket->{AttachmentStorageTemp} }, @Attachments;
                        }
                    }
                }

                if ( !$Param{IgnoreAttachmentsTemp} ) {
                    $Ticket->{AttachmentStorageClearTemp} = {};
                }

                $Ticket->{Articles} = $Articles->{Data};
            }
            elsif ( $Param{SetEmptyArticles} ) {
                $Ticket->{Articles} = [];
            }
        }
    }

    # support user id, group id, permissions params
    if ( $GroupField || scalar(@GroupQueryParam) || $UserIDQueryParam ) {
        my @GroupFilteredResult;

        # support permissions
        if ($UserIDQueryParam) {

            # get users groups
            my %GroupList = $GroupObject->PermissionUserGet(
                UserID => $UserIDQueryParam,
                Type   => $PermissionsQueryParam || 'ro',
            );

            # push user groups on the same array as groups from "GroupID" parameter
            push @GroupQueryParam, keys %GroupList;
        }

        for my $Row ( @{ $SQLSearchResult->{Data} } ) {
            if ( $Row->{QueueID} ) {

                # do not use standard queue get function as it
                # would return cached (old) queue group id
                # on queue update events
                # optionally to-do - can be optimized in a way that a parameter
                # will decide if we can use cached response
                return if !$DBObject->Prepare(
                    SQL => '
                        SELECT group_id
                        FROM   queue
                        WHERE  id = ?
                    ',
                    Bind => [
                        \$Row->{QueueID},
                    ],
                    Limit => 1,
                );

                my @Data         = $DBObject->FetchrowArray();
                my $QueueGroupID = $Data[0];

                # check if ticket exists in specified groups of user/group params
                if ( !scalar @GroupQueryParam || grep { $_ == $QueueGroupID } @GroupQueryParam ) {

                    # additionally append GroupID to the response
                    if ($GroupField) {
                        $Row->{GroupID} = $QueueGroupID;
                    }
                    push @GroupFilteredResult, $Row;
                }

            }
        }
        return {
            Success => $SQLSearchResult->{Success},
            Data    => \@GroupFilteredResult,
        };
    }
    return $SQLSearchResult;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchTicketESObject->ValidFieldsPrepare(
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

    my $SearchQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Object}");

    my $Fields         = $Self->{Fields};
    my $ExternalFields = $Self->{ExternalFields};
    my %ValidFields;

    # when no fields are specified use all standard fields
    # (without dynamic fields)
    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        %ValidFields = (
            Ticket => { %{$Fields}, %{$ExternalFields} }
        );

        return $Self->_PostValidFieldsPrepare(
            ValidFields => \%ValidFields,
            QueryParams => $Param{QueryParams},
        );
    }

    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $ArticleDataMIMEAttachmentObject
        = $Kernel::OM->Get('Kernel::System::Search::Object::Default::ArticleDataMIMEAttachment');

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    my %AllArticleFields    = ( %{ $SearchArticleObject->{Fields} }, %{ $SearchArticleObject->{ExternalFields} } );

    my $AttachmentBasicFields    = $ArticleDataMIMEAttachmentObject->{Fields};
    my $AttachmentExternalFields = $ArticleDataMIMEAttachmentObject->{ExternalFields};

    my %AllAttachmentFields = ( %{$AttachmentBasicFields}, %{$AttachmentExternalFields} );

    PARAMFIELD:
    for my $ParamField ( @{ $Param{Fields} } ) {

        # get information about field types if field
        # matches specified regexp
        if ( $ParamField =~ m{\A(Ticket|Article)_DynamicField_(.+)} ) {
            my $ObjectType       = $1;
            my $DynamicFieldName = $2;

            if ( $DynamicFieldName eq '*' ) {
                my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
                    ObjectType => $ObjectType,
                );

                for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
                    my $Info = $SearchQueryObject->_QueryDynamicFieldInfoGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next PARAMFIELD if !$Info->{ColumnName};
                    $ValidFields{ $ObjectType . '_DynamicField' }->{ $Info->{ColumnName} } = $Info;
                }
            }
            else {
                # get single dynamic field config
                my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                    Name => $DynamicFieldName,
                );

                next PARAMFIELD if $ObjectType ne $DynamicFieldConfig->{ObjectType};

                if ( IsHashRefWithData($DynamicFieldConfig) && $DynamicFieldConfig->{Name} ) {
                    my $Info = $SearchQueryObject->_QueryDynamicFieldInfoGet(
                        ObjectType         => $ObjectType,
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next PARAMFIELD if !$Info->{ColumnName};
                    $ValidFields{ $ObjectType . '_DynamicField' }->{ $Info->{ColumnName} } = $Info;
                }
            }
        }

        # apply "Ticket" fields
        elsif ( $ParamField =~ m{\ATicket_(.+)\z} ) {
            my $TicketField = $1;

            # get single "Ticket" field
            if ( $Fields->{$TicketField} ) {
                $ValidFields{Ticket}->{$TicketField} = $Fields->{$TicketField};
            }

            # get single field from external fields
            # that is for example "GroupID"
            elsif ( $ExternalFields->{$TicketField} ) {
                $ValidFields{Ticket}->{$TicketField} = $ExternalFields->{$TicketField};
            }

            # get all "Ticket" fields
            elsif ( $TicketField eq '*' ) {
                my $TicketFields = $ValidFields{Ticket} // {};
                %{ $ValidFields{Ticket} } = ( %{$Fields}, %{$ExternalFields}, %{$TicketFields} );
            }
        }

        # apply "Article" fields
        elsif ( $ParamField =~ m{\AArticle_(.+)\z} ) {
            my $ArticleField = $1;

            # get single "Article" field
            if ( $AllArticleFields{$ArticleField} ) {
                $ValidFields{Article}->{$ArticleField} = $AllArticleFields{$ArticleField};
            }

            # get all "Article" fields
            elsif ( $ArticleField && $ArticleField eq '*' ) {
                for my $ArticleField ( sort keys %AllArticleFields ) {
                    $ValidFields{Article}->{$ArticleField} = $AllArticleFields{$ArticleField};
                }
            }
        }

        # apply "Attachment" fields
        elsif ( $ParamField =~ m{^Attachment_(.+)$} ) {
            my $AttachmentField = $1;

            if ( $AttachmentField && $AttachmentField eq '*' ) {
                for my $AttachmentFieldName ( sort keys %AllAttachmentFields ) {
                    $ValidFields{Attachment}->{$AttachmentFieldName} = $AllAttachmentFields{$AttachmentFieldName};
                }
            }
            else {
                $ValidFields{Attachment}->{$AttachmentField} = $AllAttachmentFields{$AttachmentField};
            }
        }
    }

    return $Self->_PostValidFieldsPrepare(
        ValidFields => \%ValidFields,
        QueryParams => $Param{QueryParams},
    );
}

=head2 ObjectListIDs()

return all sql data of object ids

    my $ResultIDs = $SearchTicketObject->ObjectListIDs();

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
        ResultType          => $Param{ResultType} || 'ARRAY',
        Limit               => $Param{Limit},
        Offset              => $Param{Offset},
        IgnoreArticles      => 1,
        IgnoreDynamicFields => 1,
        NoPermissions       => 1,
    );

    # push hash data into array
    my @Result;
    if ( $SQLSearchResult->{Success} ) {
        if ( IsArrayRefWithData( $SQLSearchResult->{Data} ) ) {
            for my $SQLData ( @{ $SQLSearchResult->{Data} } ) {
                push @Result, $SQLData->{$Identifier};
            }
        }
        elsif ( defined $SQLSearchResult->{Data} ) {
            return $SQLSearchResult->{Data};
        }
    }

    return \@Result;
}

=head2 ObjectIndexQueueUpdateRule()

apply index object update rule for queries

    my $Success = $SearchBaseObject->ObjectIndexQueueUpdateRule(
        Queue      => $Queue,
        QueueToAdd => $QueueToAdd,
    );

=cut

sub ObjectIndexQueueUpdateRule {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');
    return if !IsHashRefWithData( $Param{QueueToAdd} );

    my $ObjectIDQueueToAdd    = $Param{QueueToAdd}->{ObjectID};
    my $QueryParamsQueueToAdd = $Param{QueueToAdd}->{QueryParams};

    # check if ObjectIndexUpdate by object id is to be queued
    if ($ObjectIDQueueToAdd) {
        my $QueuedOperation = $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd};
        if ($QueuedOperation) {

            # identify what operation was already queued
            my $PrevQueuedOperationName = $QueuedOperation->{FunctionName};

            # add overwrites update
            if ( $PrevQueuedOperationName eq 'ObjectIndexAdd' ) {
                return;
            }

            # do nothing
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexUpdate' ) {
                my $UpdateTicketQueuedBefore = $QueuedOperation->{AdditionalParameters}->{UpdateTicket};
                my $UpdateTicketQueuedNow    = $Param{QueueToAdd}->{AdditionalParameters}->{UpdateTicket};

                if ( $UpdateTicketQueuedNow && !$UpdateTicketQueuedBefore ) {
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->{AdditionalParameters}->{UpdateTicket}
                        = $UpdateTicketQueuedNow;
                }

                my $UpdateArticleQueuedBefore = $QueuedOperation->{AdditionalParameters}->{UpdateArticle} || '';
                my $UpdateArticleQueuedNow    = $Param{QueueToAdd}->{AdditionalParameters}->{UpdateArticle};

                if ( IsArrayRefWithData($UpdateArticleQueuedNow) && $UpdateArticleQueuedBefore ne '*' ) {
                    my $ArticlesToQueue = $UpdateArticleQueuedNow;
                    if ( IsArrayRefWithData($UpdateArticleQueuedBefore) ) {
                        my %QueuedArticleIDsBefore = map { $_ => 1 } @{$UpdateArticleQueuedBefore};
                        my %QueuedArticleIDsNow    = map { $_ => 1 } @{$ArticlesToQueue};
                        my %MergedArticleIDs      = ( %QueuedArticleIDsBefore, %QueuedArticleIDsNow );
                        my @MergedArticleIDsArray = keys %MergedArticleIDs;

                        $ArticlesToQueue = \@MergedArticleIDsArray;
                    }
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->{AdditionalParameters}->{UpdateArticle}
                        = $ArticlesToQueue;
                }
                elsif ( $UpdateArticleQueuedNow && $UpdateArticleQueuedNow eq '*' ) {
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->{AdditionalParameters}->{UpdateArticle} = '*';
                }

                my $AddArticleQueuedBefore = $QueuedOperation->{AdditionalParameters}->{AddArticle} || '';
                my $AddArticleQueuedNow    = $Param{QueueToAdd}->{AdditionalParameters}->{AddArticle};

                if ( IsArrayRefWithData($AddArticleQueuedNow) ) {
                    my $ArticlesToQueue = $AddArticleQueuedNow;
                    if ( IsArrayRefWithData($AddArticleQueuedBefore) ) {
                        my %QueuedArticleIDsBefore = map { $_ => 1 } @{$AddArticleQueuedBefore};
                        my %QueuedArticleIDsNow    = map { $_ => 1 } @{$ArticlesToQueue};
                        my %MergedArticleIDs      = ( %QueuedArticleIDsBefore, %QueuedArticleIDsNow );
                        my @MergedArticleIDsArray = keys %MergedArticleIDs;

                        $ArticlesToQueue = \@MergedArticleIDsArray;
                    }
                    $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd}->{AdditionalParameters}->{AddArticle}
                        = $ArticlesToQueue;
                }

                return;
            }

            # set overwrites update
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexSet' ) {
                return;
            }

            # should never be a case in the system, don't allow it
            elsif ( $PrevQueuedOperationName eq 'ObjectIndexRemove' ) {
                return;
            }
        }
        else {
            $Param{Queue}->{ObjectID}->{$ObjectIDQueueToAdd} = $Param{QueueToAdd};
            return 1;
        }
    }

    # check if ObjectIndexUpdate by query params is to be queued
    elsif ($QueryParamsQueueToAdd) {

        my $Context = $Param{QueueToAdd}->{Context};
        if ( !$Context ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Parameter 'Context' inside 'QueueToAdd' hash is needed!",
            );
            return;
        }

        if ( $Param{Queue}->{QueryParams}->{$Context} ) {
            $Param{Queue}->{QueryParams}->{$Context}->{Order} = $Param{Order};
            return;
        }
        else {
            $Param{Queue}->{QueryParams}->{$Context} = {
                %{ $Param{QueueToAdd} },
                Order => $Param{Order},
            };
            return 1;
        }
    }
    else {
        return;
    }

    return;
}

=head2 _PostValidFieldsPrepare()

set fields return type if not specified

    my %Fields = $SearchTicketESObject->_PostValidFieldsPrepare(
        ValidFields => $ValidFields,
    );

=cut

sub _PostValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    return () if !IsHashRefWithData( $Param{ValidFields} );

    my %ValidFields = %{ $Param{ValidFields} };

    for my $Type (qw(Ticket Article)) {
        for my $Field ( sort keys %ValidFields ) {
            if ( $ValidFields{$Type}->{$Field} ) {
                $ValidFields{$Type}->{$Field}->{ReturnType} = 'SCALAR'
                    if !$ValidFields{$Type}->{$Field}->{ReturnType};
            }
        }
    }

    return %ValidFields;
}

sub _ObjectIndexAddAction {
    my ( $Self, %Param ) = @_;

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');

    # some tickets ids with a data to index should be found
    return if !$Param{TicketIDs};

    # index ticket base values with dfs
    my $Success = $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexAdd',
    );

    return if !$Success;

    # index ticket articles
    # use article module, but specify index into
    # "Ticket", so that "ObjectIndexArticle" function will be executed
    $SearchArticleObject->ObjectIndexAdd(
        IndexInto   => 'Ticket',
        QueryParams => {
            TicketID => $Param{TicketIDs},
        },
        Index         => 'Article',
        MappingObject => $Param{MappingObject},
        ConnectObject => $Param{ConnectObject},
        EngineObject  => $Param{EngineObject},
        Config        => $Param{Config},
    );

    return $Success;
}

sub _ObjectIndexUpdateAction {
    my ( $Self, %Param ) = @_;

    my $Success             = 1;
    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');
    if ( $Param{UpdateTicket} ) {

        # index ticket base values with dfs
        $Success = $Self->SUPER::_ObjectIndexAction(
            %Param,
            Function => 'ObjectIndexUpdate',
        );
    }
    if ( $Param{AddArticle} ) {

        # add ticket articles
        $Success = $SearchArticleObject->ObjectIndexUpdateTicketArticles(
            IndexInto   => 'Ticket',
            QueryParams => {
                ArticleID => $Param{AddArticle},
            },
            Index         => 'Article',
            Action        => 'AddArticle',
            MappingObject => $Param{MappingObject},
            EngineObject  => $Param{EngineObject},
            ConnectObject => $Param{ConnectObject},
            Config        => $Param{Config},
        ) if $Success;
    }
    ARTICLE: {
        if ( $Param{UpdateArticle} ) {
            my $QueryParams = {
                ArticleID => $Param{UpdateArticle}
            };

            # update all articles
            if ( $Param{UpdateArticle} eq '*' ) {
                my @TicketIDs;

                if (
                    IsHashRefWithData( $Param{DataToIndex} )
                    &&
                    IsArrayRefWithData( $Param{DataToIndex}->{Data} )
                    )
                {
                    TICKET:
                    for my $Ticket ( @{ $Param{DataToIndex}->{Data} } ) {
                        next TICKET if !IsHashRefWithData($Ticket) || !$Ticket->{TicketID};
                        push @TicketIDs, $Ticket->{TicketID};
                    }
                }
                last ARTICLE if !scalar @TicketIDs;
                $QueryParams = {
                    TicketID => \@TicketIDs,
                };
            }

            # update ticket articles
            $Success = $SearchArticleObject->ObjectIndexUpdateTicketArticles(
                IndexInto     => 'Ticket',
                QueryParams   => $QueryParams,
                Index         => 'Article',
                Action        => 'UpdateArticle',
                MappingObject => $Param{MappingObject},
                EngineObject  => $Param{EngineObject},
                ConnectObject => $Param{ConnectObject},
                Config        => $Param{Config},
            ) if $Success;
        }
    }

    return $Success;
}

sub _ObjectIndexSetAction {
    my ( $Self, %Param ) = @_;

    my $SearchArticleObject = $Kernel::OM->Get('Kernel::System::Search::Object::Default::Article');

    return if !$Param{TicketIDs};

    # index ticket base values with dfs
    my $Success = $Self->SUPER::_ObjectIndexAction(
        %Param,
        Function => 'ObjectIndexSet',
    );

    return if !$Success;

    # index ticket articles
    $SearchArticleObject->ObjectIndexAdd(
        IndexInto   => 'Ticket',
        QueryParams => {
            TicketID => $Param{TicketIDs},
        },
        Index         => 'Article',
        MappingObject => $Param{MappingObject},
        ConnectObject => $Param{ConnectObject},
        EngineObject  => $Param{EngineObject},
        Config        => $Param{Config},
    );

    return $Success;
}

1;
