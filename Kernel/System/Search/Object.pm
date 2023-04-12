# --
# Copyright (C) 2012 Znuny GmbH, https://znuny.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Search::Object;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Search',
    'Kernel::System::Search::Object::Query',
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::JSON',
);

=head1 NAME

Kernel::System::Search::Object - search object lib

=head1 DESCRIPTION

Functions index related.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{DefaultOperatorMapping} = {
        ">="             => 'GreaterEqualThan',
        "="              => 'Equal',
        "!="             => 'NotEqual',
        "<="             => 'LowerEqualThan',
        ">"              => 'GreaterThan',
        "<"              => 'LowerThan',
        "BETWEEN"        => 'Between',
        "IS EMPTY"       => 'IsEmpty',
        "IS NOT EMPTY"   => 'IsNotEmpty',
        "IS DEFINED"     => 'IsDefined',
        "IS NOT DEFINED" => 'IsNotDefined',
        "FULLTEXT"       => 'FullText',
        "PATTERN"        => 'Pattern',
        "WILDCARD"       => 'Wildcard',
    };

    return $Self;
}

=head2 Fallback()

fallback from using advanced search

    my $Result = $SearchChildObject->Fallback(
        IndexName    => $IndexName,
        QueryParams  => $QueryParams,
        IndexCounter => 1,            # define which index in order is searched
    );

=cut

sub Fallback {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(IndexName)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $Result;
    my $IndexName = $Param{IndexName};

    my $IsValid = $Self->IndexIsValid(
        IndexName => $IndexName,
    );

    return if !$IsValid;
    my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::${IndexName}");

    my $ValidResultType = $Self->ValidResultType(
        SupportedResultTypes => $SearchIndexObject->{SupportedResultTypes},
        ResultType           => $Param{ResultType},
    );

    # when not valid result type
    # is specified, ignore response
    return if !$ValidResultType;

    $Result->{$IndexName} = $SearchIndexObject->Fallback(
        %Param,
        QueryParams => $Param{QueryParams},
        ResultType  => $ValidResultType,
    );

    $Result->{ResultType} = $ValidResultType;

    return $Result;
}

=head2 QueryPrepare()

prepare query for active engine with specified operation

    my $Result = $SearchChildObject->QueryPrepare(
        Config          => $Config,
        MappingObject   => $MappingObject,
        Operation       => $Operation,
    );

=cut

sub QueryPrepare {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw( Config MappingObject Operation )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $FunctionName = '_QueryPrepare' . $Param{Operation};

    my $Result = $Self->$FunctionName(
        %Param
    );

    return $Result;
}

=head2 IndexIsValid()

Check if specified index is valid -
registration with module validity check.

    my $IsValid = $SearchChildObject->IndexIsValid(
        IndexName => "ticket",
        RealName => 1, # optional
    );

=cut

sub IndexIsValid {
    my ( $Self, %Param ) = @_;

    my $SearchObject = $Kernel::OM->Get('Kernel::System::Search');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(IndexName)) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!",
        );
        return;
    }

    my %RegisteredIndexes = %{ $SearchObject->{Config}->{RegisteredIndexes} };
    my $IndexName = $Param{IndexName};    # this variable will hold friendly name of index (raw/not real)

    if ( $Param{RealName} ) {
        my %ReverseRegisteredIndexes = reverse %{ $SearchObject->{Config}->{RegisteredIndexes} };
        $IndexName = $ReverseRegisteredIndexes{ $Param{IndexName} };
    }

    # register check
    return if !$IndexName || !$RegisteredIndexes{$IndexName};
    my $IsRegistered = $RegisteredIndexes{$IndexName};

    # module validity check
    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Default::$IndexName",
        Silent => 1
    );

    return $IndexName    if $Loaded && $Param{RealName};
    return $IsRegistered if $Loaded && !$Param{RealName};
    return;
}

=head2 ValidResultType()

check result type, set 'ARRAY' by default

    my $ResultType = $SearchChildObject->ValidResultType(
        SupportedResultTypes => $SupportedResultTypes,
        ResultType           => $ResultType,
    );

=cut

sub ValidResultType {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(SupportedResultTypes)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    # return array ref as default
    my $ResultType = $Param{ResultType} ||= 'ARRAY';

    if ( !$Param{SupportedResultTypes}->{$ResultType} ) {
        $LogObject->Log(
            Priority => 'error',
            Message =>
                "Specified result type: $Param{ResultType} isn't supported!",
        );
        return;
    }

    return $ResultType;
}

=head2 ValidFieldsPrepare()

validates fields for object and return only valid ones

    my %Fields = $SearchChildObject->ValidFieldsPrepare(
        Fields => $Fields,     # optional
        Object => $ObjectName,
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

    if ( exists &{"$IndexSearchObject->{Module}::ValidFieldsPrepare"} ) {
        return $IndexSearchObject->ValidFieldsPrepare(%Param);
    }

    my $Fields = $IndexSearchObject->{Fields};
    my %ValidFields;

    if ( !IsArrayRefWithData( $Param{Fields} ) ) {
        %ValidFields = %{$Fields};

        return $Self->_PostValidFieldsPrepare(
            ValidFields => \%ValidFields,
        );
    }

    FIELD:
    for my $ParamField ( @{ $Param{Fields} } ) {
        if ( $ParamField =~ m{^$Param{Object}_(.+)$} ) {
            my $Field = $1;

            if ( $Fields->{$Field} ) {
                $ValidFields{$Field} = $Fields->{$Field};
            }
            elsif ( $Field eq '*' ) {
                %ValidFields = %{$Fields};
            }
        }
    }

    return $Self->_PostValidFieldsPrepare(
        ValidFields => \%ValidFields,
    );
}

=head2 IndexObjectQueueEntry()

queues operations for indexes

    my $Success = $SearchChildObject->IndexObjectQueueEntry(
        Index => 'Ticket',
        Value => {
            Operation => 'ObjectIndexSet',

            ObjectID => 1,
            # OR
            QueryParams => { .. },
            Context     => 'Identifier_for_query', # needed if QueryParams specified
        }
    );

=cut

sub IndexObjectQueueEntry {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Index Value)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    if ( !$Param{Value}->{Operation} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Parameter "Operation" inside Value hash is needed!',
        );
        return;
    }

    if ( !$Param{Value}->{QueryParams} && !$Param{Value}->{ObjectID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Either "QueryParams" or "ObjectID" inside Value hash is needed!',
        );
        return;
    }

    if ( $Param{Value}->{QueryParams} && !$Param{Value}->{Context} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Required "Context" when using "QueryParams"!',
        );
        return;
    }

    return if !$Self->IndexIsValid( IndexName => $Param{Index} );

    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
    my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");

    my $Queue = $Self->IndexObjectQueueGet(
        Index => $Param{Index},
    ) || {};

    my $SuccessCode = $SearchIndexObject->ObjectIndexQueueApplyRules(
        Queue      => $Queue,
        QueueToAdd => $Param{Value},
    );

    return $SuccessCode;
}

=head2 IndexObjectQueueGet()

get queued object data

    my $Data = $SearchChildObject->IndexObjectQueueGet(
        Index     => 'Ticket',         # required
        ObjectID  => [ 1 ],            # optional, possible: array, scalar
        Context   => 'some-context',   # optional
        Operation => 'ObjectIndexAdd', # optional
        Order     => [1, 2, 3, 4];     # optional, possible: array, scalar
    );

=cut

sub IndexObjectQueueGet {
    my ( $Self, %Param ) = @_;

    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    NEEDED:
    for my $Needed (qw( Index )) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $SQL = 'SELECT   id, object_id, entry_context,
                        entry_data, operation, entry_order, query_params
               FROM     search_object_operation_queue
               WHERE    index_name = ?';

    my @BindValues = ( \$Param{Index} );

    my @ObjectID = IsArrayRefWithData( $Param{ObjectID} ) ? @{ $Param{ObjectID} } : ( $Param{ObjectID} );

    if ( $ObjectID[0] ) {
        my @ParamBindObjectID = map {'?,'} @ObjectID;
        chop $ParamBindObjectID[-1];
        $SQL .= " AND object_id IN (@ParamBindObjectID)";
        for my $ID (@ObjectID) {
            push @BindValues, \$ID;
        }
    }
    if ( $Param{Operation} ) {
        $SQL .= ' AND operation = ?';
        push @BindValues, \$Param{Operation};
    }
    if ( $Param{Context} ) {
        $SQL .= ' AND entry_context = ?';
        push @BindValues, \$Param{Context};
    }

    my @Order = IsArrayRefWithData( $Param{Order} ) ? @{ $Param{Order} } : ( $Param{Order} );
    if ( $Order[0] ) {
        my @ParamBindOrder = map {'?,'} @Order;
        chop $ParamBindOrder[-1];
        $SQL .= " AND entry_order IN (@ParamBindOrder)";
        for my $Number (@Order) {
            push @BindValues, \$Number;
        }
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@BindValues,
    );

    my $Data;
    my $LastOrder = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my $DataDecoded;

        if ( $Row[3] ) {
            $DataDecoded = $JSONObject->Decode(
                Data => $Row[3],
            );
        }

        if ( $Row[1] ) {
            push @{ $Data->{ObjectID}->{ $Row[1] } }, {
                ID        => $Row[0],
                Data      => $DataDecoded,
                Operation => $Row[4],
                Order     => $Row[5],
            };
        }
        elsif ( $Row[2] ) {
            my $QueryParamsDecoded;
            if ( defined $Row[6] ) {
                $QueryParamsDecoded = $JSONObject->Decode(
                    Data => $Row[6],
                );
            }
            push @{ $Data->{QueryParams}->{ $Row[2] } }, {
                ID          => $Row[0],
                Data        => $DataDecoded,
                Operation   => $Row[4],
                Order       => $Row[5],
                QueryParams => $QueryParamsDecoded,
            };
        }

        # save last order number
        if ( defined $Row[5] && ( $LastOrder < $Row[5] ) ) {
            $LastOrder = $Row[5];
        }
    }

    if ( defined $Data ) {
        $Data->{LastOrder} = $LastOrder;
    }

    return $Data;
}

=head2 IndexObjectQueueAdd()

add object of specified index and operation to the queue

    my $Success = $SearchChildObject->IndexObjectQueueAdd(
        Index     => 'Ticket',         # required
        Operation => 'ObjectIndexAdd', # required
        Data      => {..}              # optional

        # required:
        ObjectID  => 1,
        # or
        Context => 'some-context',
        Order   => 1,
    );

=cut

sub IndexObjectQueueAdd {
    my ( $Self, %Param ) = @_;

    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    NEEDED:
    for my $Needed (qw(Operation Index)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    if ( $Param{ObjectID} && $Param{Context} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Use either "ObjectID" or "Context" parameter!',
        );
        return;
    }

    my $SQL = 'INSERT INTO search_object_operation_queue
               (operation, index_name';

    my @Binds = ( \$Param{Operation}, \$Param{Index} );

    my $ValuesStrg = '?, ?, ?';

    if ( $Param{ObjectID} ) {
        my $Exists = $Self->IndexObjectQueueExists(
            ObjectID  => $Param{ObjectID},
            Index     => $Param{Index},
            Operation => $Param{Operation},
        );
        if ($Exists) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Object to queue already exists with the same object id!',
            );
            return;
        }
        $SQL .= ', object_id';
        push @Binds, \$Param{ObjectID};
    }
    elsif ( $Param{Context} ) {
        if ( !defined $Param{Order} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => '"Context" require "Order" parameter!',
            );
            return;
        }

        $ValuesStrg .= ', ?';

        my $Exists = $Self->IndexObjectQueueExists(
            Context   => $Param{Context},
            Index     => $Param{Index},
            Operation => $Param{Operation},
        );
        if ($Exists) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Object to queue already exists with the same context!',
            );
            return;
        }
        $SQL .= ', entry_context';
        push @Binds, \$Param{Context};

        my $QueryParams = $JSONObject->Encode(
            Data => $Param{QueryParams},
        );

        $SQL .= ', query_params';
        push @Binds, \$QueryParams;

        if ( defined $Param{Order} ) {
            $SQL .= ', entry_order';
            push @Binds, \$Param{Order};
            $ValuesStrg .= ', ?';
        }
    }

    if ( $Param{Data} ) {
        my $JSON = $JSONObject->Encode(
            Data => $Param{Data},
        );
        $SQL .= ', entry_data';
        push @Binds, \$JSON;
        $ValuesStrg .= ', ?';
    }

    $SQL .= ") VALUES ($ValuesStrg)";

    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => \@Binds,
    );

    return 1;
}

=head2 IndexObjectQueueUpdate()

update data of specified queue entry

    my $Success = $SearchChildObject->IndexObjectQueueUpdate(
        ID          => 1,                     # required
        Operation   => 'ObjectIndexAdd',      # optional
        Order       => 1,                     # optional
        Context     => 'some-unique-context', # optional
        QueryParams => {TicketID => 1},       # optional
        Data        => {data1 => 2},          # optional
        ObjectID    => 10,                    # optional
        IndexName   => 'Ticket',              # optional
    );

=cut

sub IndexObjectQueueUpdate {
    my ( $Self, %Param ) = @_;

    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    NEEDED:
    for my $Needed (qw(ID)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $Exists = $Self->IndexObjectQueueExists(
        ID => $Param{ID},
    );

    my $SQL = 'UPDATE search_object_operation_queue
               SET';
    my $SQLSet = '';
    my @Binds;

    if ( defined $Param{Data} ) {
        my $JSON;
        if ( !$Param{Data} ) {
            $JSON = '';
        }
        else {
            $JSON = $JSONObject->Encode(
                Data => $Param{Data},
            );
        }
        $SQLSet .= ' entry_data = ?,';
        push @Binds, \$JSON;
    }
    if ( defined $Param{QueryParams} ) {
        my $JSON = $JSONObject->Encode(
            Data => $Param{QueryParams},
        );

        $SQLSet .= ' query_params = ?,';
        push @Binds, \$JSON;
    }
    if ( $Param{Operation} ) {
        $SQLSet .= ' operation = ?,';
        push @Binds, \$Param{Operation};
    }
    if ( defined $Param{Order} ) {
        $SQLSet .= ' entry_order = ?,';
        push @Binds, \$Param{Order};
    }
    if ( defined $Param{Context} ) {
        $SQLSet .= ' entry_context = ?,';
        push @Binds, \$Param{Context};
    }
    if ( $Param{ObjectID} ) {
        $SQLSet .= ' object_id = ?,';
        push @Binds, \$Param{ObjectID};
    }
    if ( $Param{IndexName} ) {
        $SQLSet .= ' index_name = ?,';
        push @Binds, \$Param{IndexName};
    }

    # nothing to update
    if ( !$SQLSet ) {
        return;
    }

    chop($SQLSet);

    $SQL .= $SQLSet;
    $SQL .= ' WHERE id = ?';
    push @Binds, \$Param{ID};

    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => \@Binds,
    );

    return 1;
}

=head2 IndexObjectQueueExists()

check if object data was added into the operation queue

    my $ID = $SearchChildObject->IndexObjectQueueExists(
        ID        => 1,

        # or

        Index     => 'Ticket',
        Operation => 'ObjectIndexAdd',

        ObjectID  => 1,
        # or
        Context => 'my_context',
    );

=cut

sub IndexObjectQueueExists {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if (
        !$Param{ID}
        &&
        (
            !$Param{Operation}
            && !$Param{Index}
            && !$Param{Context}
            && !$Param{ObjectID}
        )
        )
    {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'No valid parameters!'
        );
        return;
    }

    my $SQL = 'SELECT id FROM search_object_operation_queue WHERE 1 = 1';

    my @Binds;
    if ( $Param{ID} ) {
        $SQL .= ' AND id = ?';
        push @Binds, \$Param{ID};
    }
    else {
        if ( $Param{Operation} ) {
            $SQL .= ' AND operation = ?';
            push @Binds, \$Param{Operation};
        }
        if ( $Param{Index} ) {
            $SQL .= ' AND index_name = ?';
            push @Binds, \$Param{Index};
        }
        if ( $Param{Context} ) {
            $SQL .= ' AND entry_context = ?';
            push @Binds, \$Param{Context};
        }
        elsif ( $Param{ObjectID} ) {
            $SQL .= ' AND object_id = ?';
            push @Binds, \$Param{ObjectID};
        }
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Binds,
    );

    my @Data = $DBObject->FetchrowArray();

    return $Data[0];
}

=head2 IndexObjectQueueDelete()

delete queued object data

    my $Success = $SearchChildObject->IndexObjectQueueDelete(
        ID  => 1, # required

        # or

        Index     => 'Ticket',         # required
        Operation => 'ObjectIndexAdd', # optional

        ObjectID => 1,
        # or
        Context => 'some-context',
    );

=cut

sub IndexObjectQueueDelete {
    my ( $Self, %Param ) = @_;

    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if (
        !$Param{ID}
        && !$Param{ObjectID}
        &&
        !$Param{Operation} && !$Param{Index} &&
        !$Param{Context}
        )
    {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'No valid parameters!',
        );
        return;
    }

    if ( $Param{ID} ) {
        my @ParamID = IsArrayRefWithData( $Param{ID} ) ? @{ $Param{ID} } : ( $Param{ID} );

        my @ParamBindQuery = map {'?,'} @ParamID;
        chop $ParamBindQuery[-1];

        return if !$DBObject->Do(
            SQL => "DELETE FROM search_object_operation_queue
                     WHERE id IN (@ParamBindQuery)",
            Bind => [ \$Param{ID} ],
        );

        return 1;
    }
    else {
        if ( !$Param{Index} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Parameter "Index" is needed!',
            );
            return;
        }
        my @ParamObjectID;
        my $ObjSQLColumn;
        my $SQLWhere = '1 = 1';
        my $ObjOrContextDefined;
        if ( $Param{ObjectID} ) {
            @ParamObjectID = IsArrayRefWithData( $Param{ObjectID} ) ? @{ $Param{ObjectID} } : ( $Param{ObjectID} );
            $ObjSQLColumn  = 'object_id';
            $ObjOrContextDefined = 1;
        }
        elsif ( $Param{Context} ) {
            @ParamObjectID       = IsArrayRefWithData( $Param{Context} ) ? @{ $Param{Context} } : ( $Param{Context} );
            $ObjSQLColumn        = 'entry_context';
            $ObjOrContextDefined = 1;
        }
        if ($ObjOrContextDefined) {
            my @ParamBindQuery = map {'?,'} @ParamObjectID;
            chop $ParamBindQuery[-1];
            $SQLWhere = "$ObjSQLColumn IN (@ParamBindQuery)";
        }

        my $SQL = "DELETE FROM search_object_operation_queue
                   WHERE $SQLWhere";

        my @BindValues;
        for my $BindableObjectID (@ParamObjectID) {
            push @BindValues, \$BindableObjectID;
        }

        $SQL .= ' AND index_name = ?';
        push @BindValues, \$Param{Index};

        if ( $Param{Operation} ) {
            $SQL .= ' AND operation = ?';
            push @BindValues, \$Param{Operation};
        }

        return if !$DBObject->Do(
            SQL  => $SQL,
            Bind => \@BindValues,
        );

        return 1;
    }
}

=head2 _PostValidFieldsGet()

set fields return type if not specified

    my $Fields = $SearchChildObject->_PostValidFieldsGet(
        %Param,
    );

=cut

sub _PostValidFieldsPrepare {
    my ( $Self, %Param ) = @_;

    return () if !IsHashRefWithData( $Param{ValidFields} );

    my %ValidFields = %{ $Param{ValidFields} };

    for my $Field ( sort keys %ValidFields ) {
        $ValidFields{$Field}->{ReturnType} = 'SCALAR' if !$ValidFields{$Field}->{ReturnType};
    }

    return %ValidFields;
}

=head2 _QueryPrepareSearch()

prepares query for active engine with specified object "Search" operation

    my $Result = $SearchChildObject->_QueryPrepareSearch(
        MappingObject     => $MappingObject,
        Objects           => $Objects,
        QueryParams       => $QueryParams,
        Config            => $Config,
        ResultType        => $ResultType,             # optional
    );

=cut

sub _QueryPrepareSearch {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    my $Result;
    my @Queries;

    NEEDED:
    for my $Needed (qw( Objects MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    OBJECT:
    for my $Object ( sort keys %{ $Param{Objects} } ) {
        next OBJECT if !$Object;

        my $IndexIsValid = $Self->IndexIsValid(
            IndexName => $Object,
        );

        next OBJECT if !$IndexIsValid;

        my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Object}");

        # check/set valid result type
        my $ValidResultType = $Self->ValidResultType(
            SupportedResultTypes => $IndexQueryObject->{IndexSupportedResultTypes},
            ResultType           => $Param{ResultType},
        );

        # do not build query for objects
        # with not valid result type
        next OBJECT if !$ValidResultType;

        my $Limit = $Param{Limit};

        # check if limit was specified as an array
        # for each object or as single string

        my $Data = $IndexQueryObject->Search(
            %Param,
            QueryParams   => $Param{QueryParams},
            MappingObject => $Param{MappingObject},
            Config        => $Param{Config},
            RealIndexName => $IndexQueryObject->{IndexConfig}->{IndexRealName},
            Object        => $Object,
            ResultType    => $ValidResultType,
            Fields        => $Param{Objects}->{$Object}->{Fields},
            SortBy        => $Param{Objects}->{$Object}->{SortBy},
            OrderBy       => $Param{Objects}->{$Object}->{OrderBy},
            Limit         => $Param{Objects}->{$Object}->{Limit} || $IndexQueryObject->{IndexDefaultSearchLimit},
        );

        $Data->{Object} = $Object;
        push @Queries, $Data;
    }

    $Result->{Queries} = \@Queries;

    return $Result;
}

=head2 _QueryPrepareObjectIndexAdd()

prepares query for active engine with specified object "Add" operation

    my $Result = $SearchChildObject->_QueryPrepareObjectIndexAdd(
        MappingObject   => $MappingObject,
        ObjectID        => $ObjectID,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareObjectIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Index}");

    my $Data = $IndexQueryObject->ObjectIndexAdd(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareObjectIndexSet()

prepares query for active engine with specified object "Set" operation

    my $Result = $SearchChildObject->_QueryPrepareObjectIndexSet(
        MappingObject   => $MappingObject,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareObjectIndexSet {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Index}");

    my $Data = $IndexQueryObject->ObjectIndexSet(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareObjectIndexUpdate()

prepares query for active engine with specified object "Update" operation

    my $Result = $SearchChildObject->_QueryPrepareObjectIndexUpdate(
        MappingObject   => $MappingObject,
        ObjectID        => $ObjectID,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareObjectIndexUpdate {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->ObjectIndexUpdate(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareObjectIndexRemove()

prepare query for index object removal

    my $Query = $SearchChildObject->_QueryPrepareObjectIndexRemove(
        Index         => 'Ticket',
        ObjectID      => 1,
        MappingObject => $MappingObject,
        Config        => $Config
    );

=cut

sub _QueryPrepareObjectIndexRemove {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->ObjectIndexRemove(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareIndexRemove()

prepares query for index remove operation

    my $Result = $SearchChildObject->_QueryPrepareIndexRemove(
        MappingObject   => $MappingObject,
        Config          => $Config
    );

=cut

sub _QueryPrepareIndexRemove {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    if ( !$Param{IndexName} && !$Param{IndexRealName} || $Param{IndexName} && $Param{IndexRealName} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need IndexName or IndexRealName!"
        );
        return;
    }

    my $IndexQueryObject;
    if ( $Param{IndexRealName} ) {
        $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query");
    }
    else {
        $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{IndexName}");
    }

    my $Data = $IndexQueryObject->IndexRemove(
        %Param
    );

    return $Data;
}

=head2 _QueryPrepareIndexAdd()

prepares query for index add operation

    my $Result = $SearchChildObject->_QueryPrepareIndexAdd(
        MappingObject   => $MappingObject,
        Config          => $Config
    );

=cut

sub _QueryPrepareIndexAdd {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( MappingObject Config IndexName )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{IndexName}");

    my $Data = $IndexQueryObject->IndexAdd(
        %Param
    );

    return $Data;
}

=head2 _QueryPrepareIndexList()

prepares query for index list operation

    my $Result = $SearchChildObject->_QueryPrepareIndexList(
        MappingObject   => $MappingObject,
        Config          => $Config
    );

=cut

sub _QueryPrepareIndexList {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query");

    my $Data = $IndexQueryObject->IndexList(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareIndexClear()

prepares query for index clear operation

    my $Result = $SearchChildObject->_QueryPrepareIndexClear(
        MappingObject   => $MappingObject,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareIndexClear {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexClear(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareIndexMappingSet()

prepares query for index mapping set operation

    my $Result = $SearchChildObject->_QueryPrepareIndexMappingSet(
        MappingObject   => $MappingObject,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareIndexMappingSet {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexMappingSet(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareIndexBaseInit()

prepares query for index initialization

    my $Result = $SearchChildObject->_QueryPrepareIIndexBaseInit(
        MappingObject   => $MappingObject,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareIndexBaseInit {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexBaseInit(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareIndexMappingGet()

prepares query for index mapping set operation

    my $Result = $SearchChildObject->_QueryPrepareIndexMappingGet(
        MappingObject   => $MappingObject,
        Index           => $Index,
        Config          => $Config
    );

=cut

sub _QueryPrepareIndexMappingGet {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexMappingGet(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareDiagnosticDataGet()

prepares query for diagnostic data get operation

    my $Result = $SearchChildObject->_QueryPrepareDiagnosticDataGet(
        MappingObject   => $MappingObject,
        Config          => $Config
    );

=cut

sub _QueryPrepareDiagnosticDataGet {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query");

    my $Data = $IndexQueryObject->DiagnosticDataGet(
        %Param,
    );

    return $Data;
}

=head2 _LoadModule()

loads/check module

    my $Loaded = $SearchChildObject->_LoadModule(
        Module => 'Kernel::System::Search::Object::Query::SomeModuleName',
    );

=cut

sub _LoadModule {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw(Module)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $Module = $Param{Module};

    if ( !$Self->{LoadedModules}->{$Module} ) {
        my $Loaded = $MainObject->Require(
            $Module,
            Silent => $Param{Silent},
        );
        if ( !$Loaded ) {
            return;
        }
        else {
            $Self->{LoadedModules}->{$Module} = $Loaded;
        }
    }
    return 1;
}

=head2 _QueryPrepareIndexInitialSettingsGet()

prepares query for index remove operation

    my $Result = $SearchChildObject->_QueryPrepareIndexInitialSettingsGet(
        MappingObject   => $MappingObject,
        Config          => $Config,
        Index           => $Index,
    );

=cut

sub _QueryPrepareIndexInitialSettingsGet {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexInitialSettingsGet(
        %Param,
    );

    return $Data;
}

=head2 _QueryPrepareIndexRefresh()

prepares query for index remove operation

    my $Result = $SearchChildObject->_QueryPrepareIndexRefresh(
        Index           => $Index,
        MappingObject   => $MappingObject,
        Config          => $Config,
    );

=cut

sub _QueryPrepareIndexRefresh {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    NEEDED:
    for my $Needed (qw( Index MappingObject Config )) {
        next NEEDED if $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $Needed!"
        );
        return;
    }

    my $Index = $Param{Index};

    my $IndexIsValid = $Self->IndexIsValid(
        IndexName => $Index,
    );

    return if !$IndexIsValid;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexRefresh(
        %Param,
    );

    return $Data;
}

1;
