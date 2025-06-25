USE MermaidTest;
GO
DECLARE @DatabaseName NVARCHAR(128) = 'MermaidTest';

DECLARE @dataTypes TABLE (
    COLUMN_NAME NVARCHAR(128),
    TABLE_NAME NVARCHAR(128),
    DATA_TYPE NVARCHAR(128),
    MermaidType NVARCHAR(128)
);

DECLARE @pkColumns TABLE (
    TABLE_NAME NVARCHAR(128),
    COLUMN_NAME NVARCHAR(128)
);

DECLARE @fkColumns TABLE (
    FK_TABLE NVARCHAR(128),
    FK_COLUMN NVARCHAR(128),
    PK_TABLE NVARCHAR(128),
    PK_COLUMN NVARCHAR(128)
);

DECLARE @mermaidLines TABLE (
    MermaidLine NVARCHAR(MAX)
);

DECLARE @dbTableName NVARCHAR(128);

INSERT INTO @dataTypes (COLUMN_NAME, TABLE_NAME, DATA_TYPE, MermaidType)
SELECT 
        COLUMN_NAME,
        TABLE_NAME,
        DATA_TYPE,
        CASE 
            WHEN DATA_TYPE IN ('uniqueidentifier') THEN 'uuid'
            WHEN DATA_TYPE IN ('xml') THEN 'xml'
            WHEN DATA_TYPE IN ('varbinary', 'binary', 'image') THEN 'blob'
            WHEN DATA_TYPE IN ('hierarchyid') THEN 'hierarchyid'
            WHEN DATA_TYPE IN ('geography', 'geometry') THEN 'geospatial'
            WHEN DATA_TYPE IN ('sql_variant') THEN 'sql_variant'
            WHEN DATA_TYPE IN ('timestamp', 'rowversion') THEN 'timestamp'
            WHEN DATA_TYPE IN ('json') THEN 'json'
            WHEN DATA_TYPE IN ('int', 'bigint', 'smallint', 'tinyint') THEN 'integer'
            WHEN DATA_TYPE IN ('char', 'nchar', 'varchar', 'nvarchar', 'text', 'ntext') THEN 'string'
            WHEN DATA_TYPE IN ('bit') THEN 'boolean'
            WHEN DATA_TYPE IN ('datetime', 'smalldatetime', 'date', 'datetime2', 'datetimeoffset', 'time') THEN 'datetime'
            WHEN DATA_TYPE IN ('decimal', 'numeric', 'money', 'smallmoney', 'float', 'real') THEN 'decimal'
            ELSE 'string'
        END AS MermaidType
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE (
        TABLE_CATALOG = @DatabaseName
    );

INSERT INTO @pkColumns (TABLE_NAME, COLUMN_NAME)
SELECT 
        KU.TABLE_NAME,
        KU.COLUMN_NAME
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS TC
    INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS KU
    ON TC.CONSTRAINT_NAME = KU.CONSTRAINT_NAME
    WHERE (
        TC.CONSTRAINT_TYPE = 'PRIMARY KEY'
        AND KU.TABLE_CATALOG = @DatabaseName
    );

INSERT INTO @fkColumns (FK_TABLE, FK_COLUMN, PK_TABLE, PK_COLUMN)
SELECT 
        FK.TABLE_NAME AS FK_TABLE,
        CU.COLUMN_NAME AS FK_COLUMN,
        PK.TABLE_NAME AS PK_TABLE,
        PT.COLUMN_NAME AS PK_COLUMN
    FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS C
    INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS FK
    ON C.CONSTRAINT_NAME = FK.CONSTRAINT_NAME
    INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS PK
    ON C.UNIQUE_CONSTRAINT_NAME = PK.CONSTRAINT_NAME
    INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU
    ON C.CONSTRAINT_NAME = CU.CONSTRAINT_NAME
    INNER JOIN (
        SELECT  i1.TABLE_NAME, 
                i2.COLUMN_NAME
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS i1
        INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE i2
        ON i1.CONSTRAINT_NAME = i2.CONSTRAINT_NAME
        WHERE (
            i1.CONSTRAINT_TYPE = 'PRIMARY KEY'
        )
    ) PT
    ON PT.TABLE_NAME = PK.TABLE_NAME
    WHERE (
        FK.TABLE_CATALOG = @DatabaseName
    );

INSERT INTO @mermaidLines (MermaidLine)
SELECT '```mermaid' AS MermaidLine
UNION ALL
SELECT 'erDiagram' AS MermaidLine

DECLARE tableNameCursor CURSOR FAST_FORWARD 
FOR SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE (
            TABLE_TYPE = 'BASE TABLE'
        );

OPEN tableNameCursor;
FETCH NEXT FROM tableNameCursor INTO @dbTableName;

WHILE (
    @@FETCH_STATUS = 0
)
BEGIN

    INSERT INTO @mermaidLines (MermaidLine)
    SELECT @dbTableName + ' {' AS MermaidLine;

    INSERT INTO @mermaidLines (MermaidLine)
    SELECT  '  ' + d.MermaidType + ' ' + c.COLUMN_NAME + ' ' +
            CASE 
                WHEN pk.COLUMN_NAME IS NOT NULL AND fk.FK_COLUMN IS NOT NULL THEN ' PK, FK'
                WHEN pk.COLUMN_NAME IS NOT NULL AND fk.FK_COLUMN IS NULL THEN ' PK'
                WHEN pk.COLUMN_NAME IS NULL AND fk.FK_COLUMN IS NOT NULL THEN ' FK'
                ELSE ''
            END AS MermaidLine
        FROM INFORMATION_SCHEMA.COLUMNS c
        JOIN @dataTypes d ON c.TABLE_NAME = d.TABLE_NAME AND c.COLUMN_NAME = d.COLUMN_NAME
        LEFT JOIN @pkColumns pk ON c.TABLE_NAME = pk.TABLE_NAME AND c.COLUMN_NAME = pk.COLUMN_NAME
        LEFT JOIN @fkColumns fk ON c.TABLE_NAME = fk.FK_TABLE AND c.COLUMN_NAME = fk.FK_COLUMN
        WHERE (
            c.TABLE_CATALOG = @DatabaseName
        )
        AND (
            c.TABLE_NAME = @dbTableName
        )
        ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;

    INSERT INTO @mermaidLines (MermaidLine)
    SELECT '}' AS MermaidLine;

    FETCH NEXT FROM tableNameCursor INTO @dbTableName;
END

CLOSE tableNameCursor;
DEALLOCATE tableNameCursor;

-- Relationships
INSERT INTO @mermaidLines (MermaidLine)
SELECT fk.FK_TABLE + ' }o--|| ' + fk.PK_TABLE + ' : "FK_' + fk.FK_TABLE + '_' + fk.FK_COLUMN + '"' AS MermaidLine
FROM @fkColumns fk
UNION ALL
SELECT '```' AS MermaidLine

SELECT MermaidLine
    FROM @mermaidLines;