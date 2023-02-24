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
    'Kernel::System::Cache',
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

=head2 IndexObjectQueueAdd()

add cached operations for indexes to the queue

    my $Success = $SearchChildObject->IndexObjectQueueAdd(
        Index => 'Ticket',
        Value => {
            FunctionName => 'ObjectIndexSet',

            ObjectID => 1,
            # OR
            QueryParams => { .. },
            Context => 'Identifier_for_query', # needed if QueryParams specified
        }
    );

=cut

sub IndexObjectQueueAdd {
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

    if ( !$Param{Value}->{FunctionName} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Parameter "FunctionName" inside Value hash is needed!',
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

    my $CacheObject       = $Kernel::OM->Get('Kernel::System::Cache');
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
    my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::Default::$Param{Index}");

    my $IndexationQueueConfig = $ConfigObject->Get("SearchEngine::IndexationQueue") // {};
    my $TTL                   = $IndexationQueueConfig->{Settings}->{TTL} || 180;

    my $Queue = $CacheObject->Get(
        Type => 'SearchEngineIndexQueue',
        Key  => "Index::$Param{Index}",
    ) || {};

    my $QueueChanged = $SearchIndexObject->ObjectIndexQueueApplyRules(
        Queue      => $Queue,
        QueueToAdd => $Param{Value},
    );

    $CacheObject->Set(
        Type           => 'SearchEngineIndexQueue',
        Key            => "Index::$Param{Index}",
        Value          => $Queue,
        TTL            => $TTL,
        CacheInBackend => 1,
        CacheInMemory  => 0,
    );

    return 1;
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
