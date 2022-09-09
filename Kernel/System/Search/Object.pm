# --
# Copyright (C) 2012-2022 Znuny GmbH, http://znuny.com/
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
    'Kernel::Config',
    'Kernel::System::Search',
    'Kernel::System::Search::Object',
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
        "<="             => 'LowerEqualThan',
        ">"              => 'GreaterThan',
        "<"              => 'LowerThan',
        "IS EMPTY"       => 'IsEmpty',
        "IS NOT EMPTY"   => 'IsNotEmpty',
        "IS DEFINED"     => 'IsDefined',
        "IS NOT DEFINED" => 'IsNotDefined',
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
    for my $Needed (qw(IndexName QueryParams IndexCounter)) {

        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $Result;
    my $IndexName = $Param{IndexName};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::${IndexName}",
    );

    # TODO support for not loaded module
    return if !$Loaded;
    my $SearchIndexObject = $Kernel::OM->Get("Kernel::System::Search::Object::${IndexName}");

    my $ValidResultType = $Self->ValidResultType(
        SupportedResultTypes => $SearchIndexObject->{SupportedResultTypes},
        ResultType           => $Param{ResultType},
    );

    # when not valid result type
    # is specified, ignore response
    return if !$ValidResultType;

    my $Limit = $Param{Limit};

    # check if limit was specified as an array
    # for each object or as single string
    if ( $Param{MultipleLimit} ) {
        $Limit = $Param{Limit}->[ $Param{IndexCounter} ];
    }

    $Result->{$IndexName} = $SearchIndexObject->Fallback(
        %Param,
        QueryParams => $Param{QueryParams},
        ResultType  => $ValidResultType,
        Limit       => $Limit,
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

    for my $Name (qw( Config MappingObject Operation )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
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
        Name => "ticket",
        RealName => 1, # optional
    );

=cut

sub IndexIsValid {
    my ( $Self, %Param ) = @_;

    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
    my $SearchObject      = $Kernel::OM->Get('Kernel::System::Search');
    my $SearchChildObject = $Kernel::OM->Get('Kernel::System::Search::Object');
    my $MainObject        = $Kernel::OM->Get('Kernel::System::Main');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');

    for my $Name (qw(IndexName)) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    if ( $Param{RealName} ) {
        INDEX:
        for my $Index ( @{ $SearchObject->{Config}->{RegisteredIndexes} } ) {

            # get valid modules
            my $Loaded = $SearchChildObject->_LoadModule(
                Module => "Kernel::System::Search::Object::$Index",
                Silent => 1
            );

            next INDEX if !$Loaded;

            # search for index name inside module
            my $IndexObject   = $Kernel::OM->Get("Kernel::System::Search::Object::$Index");
            my $IndexRealName = $IndexObject->{Config}->{IndexRealName};

            # index real name check
            return 1 if $IndexRealName eq $Param{IndexName};
        }
        return;

        # TODO later: check if this else section of code will be used at all - if not delete
        # it checks single index name validity
    }
    else {
        # register check
        my $IsRegistered = grep { $_ eq $Param{IndexName} } @{ $SearchObject->{Config}->{RegisteredIndexes} };
        return if !$IsRegistered;

        # module validity check
        my $Loaded = $SearchChildObject->_LoadModule(
            Module => "Kernel::System::Search::Object::$Param{IndexName}",
            Silent => 1
        );

        return 1 if $Loaded;
    }

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

    my $Result = {};
    my @Queries;

    for my $Name (qw( QueryParams Objects MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    OBJECT:
    for ( my $i = 0; $i < scalar @{ $Param{Objects} }; $i++ ) {
        my $Index = $Param{Objects}->[$i];

        my $Loaded = $Self->_LoadModule(
            Module => "Kernel::System::Search::Object::Query::${Index}",
        );

        # TODO support for not loaded module
        next OBJECT if !$Loaded;

        my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Index}");

        my $Fields;

        if ( $Param{Fields} ) {
            for my $Field ( @{ $Param{Fields}->[$i] } ) {
                push @{$Fields}, $IndexQueryObject->{IndexFields}->{$Field};
            }
        }

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
        if ( $Param{MultipleLimit} ) {
            $Limit = $Param{Limit}->[$i];
        }

        my $Data = $IndexQueryObject->Search(
            %Param,
            QueryParams   => $Param{QueryParams},
            MappingObject => $Param{MappingObject},
            Config        => $Param{Config},
            Object        => $Index,
            ResultType    => $ValidResultType,
            Fields        => $Fields,
            SortBy        => $Param{SortBy}->[$i],
            OrderBy       => $Param{OrderBy}->[$i] || $Param{OrderBy},
            Limit         => $Limit || $IndexQueryObject->{IndexDefaultSearchLimit},
        );

        $Data->{Object} = $Index;
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

    for my $Name (qw( Index ObjectID MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    # TODO support for not loaded module
    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::${Index}");

    my $Data = $IndexQueryObject->ObjectIndexAdd(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
        ObjectID      => $Param{ObjectID},
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

    for my $Name (qw( Index ObjectID MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    # TODO support for not loaded module
    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->ObjectIndexUpdate(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
        ObjectID      => $Param{ObjectID},
    );

    return $Data;
}

=head2 _QueryPrepareObjectIndexGet()

TO-DO

=cut

sub _QueryPrepareObjectIndexGet {
    my ( $Self, %Param ) = @_;

    return 1;
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

    for my $Name (qw( Index ObjectID MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    # TODO support for not loaded module
    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->ObjectIndexRemove(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
        ObjectID      => $Param{ObjectID},
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

            # TO-DO support not loaded object
            return;
        }
        else {
            $Self->{LoadedModules}->{$Module} = $Loaded;
        }
    }
    return 1;
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

    for my $Name (qw( Index MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexClear(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
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

    for my $Name (qw( Index MappingObject Config )) {
        if ( !$Param{$Name} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Name!"
            );
            return;
        }
    }

    my $Index = $Param{Index};

    my $Loaded = $Self->_LoadModule(
        Module => "Kernel::System::Search::Object::Query::${Index}",
    );

    return if !$Loaded;

    my $IndexQueryObject = $Kernel::OM->Get("Kernel::System::Search::Object::Query::$Param{Index}");

    my $Data = $IndexQueryObject->IndexMappingSet(
        %Param,
        MappingObject => $Param{MappingObject},
        Config        => $Param{Config},
    );

    return $Data;
}

1;
