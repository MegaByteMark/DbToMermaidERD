/*
MIT License

Copyright (c) 2025 MegaByteMark

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

-- TODO: change the database name to your own
USE MermaidTest;
GO
DECLARE @DatabaseName NVARCHAR(128) = DB_NAME();

DECLARE @dataTypes TABLE (
    COLUMN_NAME NVARCHAR(128),
    TABLE_NAME  NVARCHAR(128),
    DATA_TYPE   NVARCHAR(128),
    MermaidType NVARCHAR(128)
);

DECLARE @pkColumns TABLE (
    TABLE_NAME  NVARCHAR(128),
    COLUMN_NAME NVARCHAR(128)
);

DECLARE @fkColumns TABLE (
    FK_TABLE    NVARCHAR(128),
    FK_COLUMN   NVARCHAR(128),
    PK_TABLE    NVARCHAR(128),
    PK_COLUMN   NVARCHAR(128)
);

DECLARE @mermaidLines TABLE (
    MermaidLine NVARCHAR(MAX)
);

DECLARE @dbTableName NVARCHAR(128);

-- Cache the data types, primary keys, and foreign keys
-- to avoid multiple calls to INFORMATION_SCHEMA
-- and to improve performance
-- This is especially useful for large databases
-- and will help reduce the execution time of the script
-- You can modify the data types and MermaidType mapping as needed
-- The MermaidType mapping is used to define how the data types are represented in the Mermaid diagram
-- Make sure to adjust the MermaidType mapping to match your requirements
-- The MermaidType is used to define how the data types are represented in the Mermaid diagram
INSERT INTO @dataTypes (
    COLUMN_NAME, 
    TABLE_NAME, 
    DATA_TYPE, 
    MermaidType
)
SELECT 
        COLUMN_NAME,
        TABLE_NAME,
        DATA_TYPE,
        --TODO: Modify this CASE statement to match your Mermaid type requirements
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

-- Get primary keys
INSERT INTO @pkColumns (
    TABLE_NAME, 
    COLUMN_NAME
)
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

-- Get foreign keys
INSERT INTO @fkColumns (
    FK_TABLE, 
    FK_COLUMN, 
    PK_TABLE, 
    PK_COLUMN
)
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

-- Start building the Mermaid diagram
-- The diagram will be in the form of an Entity-Relationship Diagram (ERD)
-- The Mermaid diagram will be generated in the following format:
-- ```mermaid
-- erDiagram
--   TableName {
--     ColumnName DataType PK
--     ColumnName DataType
--   }
-- ```
INSERT INTO @mermaidLines (MermaidLine)
SELECT '```mermaid' AS MermaidLine
UNION ALL
SELECT 'erDiagram' AS MermaidLine

-- Iterate through each table in the database
-- and generate the Mermaid diagram for each table
-- The Mermaid diagram will include the table name, columns, data types, and primary/foreign keys
-- We need to use a cursor to iterate through each table
-- This is necessary because we need to generate the Mermaid diagram for each table separately
-- Using a cursor allows us to fetch each table name one by one
-- and generate the Mermaid diagram for that table
-- This is more efficient than generating the Mermaid diagram for all tables at once
-- and allows us to control the flow of the script
-- We use FAST_FORWARD cursor to improve performance by only allowing forward-only reads
DECLARE tableNameCursor CURSOR FAST_FORWARD 
FOR SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE (
            TABLE_TYPE = 'BASE TABLE'
        );

OPEN tableNameCursor;

FETCH 
    NEXT 
    FROM tableNameCursor 
    INTO @dbTableName;

WHILE (
    @@FETCH_STATUS = 0
)
BEGIN
    INSERT INTO @mermaidLines (
        MermaidLine
    )
    SELECT @dbTableName + ' {' AS MermaidLine;

    INSERT INTO @mermaidLines (
        MermaidLine
    )
    SELECT  '  ' + d.MermaidType + ' ' + c.COLUMN_NAME + ' ' +
            CASE 
                -- Check if column is both a primary key and a foreign key e.g. composite key of a junction table
                WHEN pk.COLUMN_NAME IS NOT NULL 
                    AND fk.FK_COLUMN IS NOT NULL 
                    THEN ' PK, FK'
                -- Check if column is a primary key
                WHEN pk.COLUMN_NAME IS NOT NULL 
                    AND fk.FK_COLUMN IS NULL 
                    THEN ' PK'
                -- Check if column is a foreign key
                WHEN pk.COLUMN_NAME IS NULL 
                    AND fk.FK_COLUMN IS NOT NULL 
                    THEN ' FK'
                ELSE ''
            END AS MermaidLine
        FROM INFORMATION_SCHEMA.COLUMNS c
        INNER JOIN @dataTypes d 
            ON c.TABLE_NAME = d.TABLE_NAME 
            AND c.COLUMN_NAME = d.COLUMN_NAME
        LEFT JOIN @pkColumns pk 
            ON c.TABLE_NAME = pk.TABLE_NAME 
            AND c.COLUMN_NAME = pk.COLUMN_NAME
        LEFT JOIN @fkColumns fk 
            ON c.TABLE_NAME = fk.FK_TABLE 
            AND c.COLUMN_NAME = fk.FK_COLUMN
        WHERE (
            c.TABLE_CATALOG = @DatabaseName
        )
        AND (
            c.TABLE_NAME = @dbTableName
        )
        ORDER BY    c.TABLE_NAME, 
                    c.ORDINAL_POSITION;

    -- Close the current table definition
    INSERT INTO @mermaidLines (
        MermaidLine
    )
    SELECT '}' AS MermaidLine;

    -- Don't forget this!
    FETCH 
        NEXT 
        FROM tableNameCursor 
        INTO @dbTableName;
END

-- Close and deallocate the cursor
-- This is important to free up resources and avoid memory leaks
CLOSE tableNameCursor;
DEALLOCATE tableNameCursor;

-- Now we have the basic structure of the Mermaid diagram
-- Next, we will add the foreign key relationships to the diagram
-- The foreign key relationships will be represented as lines connecting the tables
-- The format for the foreign key relationships is:
-- FK_TableName }o--|| PK_TableName : "FK_FK_TableName_FK_ColumnName"
-- This format indicates that the foreign key table has a one-to-many relationship
-- with the primary key table, and the relationship is labeled with the foreign key column name
INSERT INTO @mermaidLines (
    MermaidLine
)
SELECT  fk.FK_TABLE + 
        CASE 
            -- One-to-one: FK column is unique or a Primary Key in Foreign Key table AND is the only column in the constraint
            WHEN EXISTS (
                SELECT NULL
                FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
                INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE ku
                    ON tc.CONSTRAINT_NAME = ku.CONSTRAINT_NAME
                WHERE 
                    tc.TABLE_NAME = fk.FK_TABLE
                    AND (
                        tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
                        OR tc.CONSTRAINT_TYPE = 'UNIQUE'
                    )
                    AND ku.COLUMN_NAME = fk.FK_COLUMN
                    AND (
                        SELECT COUNT(*)
                        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
                        WHERE kcu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME
                        AND kcu.TABLE_NAME = tc.TABLE_NAME
                    ) = 1
            )
            THEN ' ||--|| '
            -- The only other option is one-to-many
            -- If the FK column is not unique, it is a one-to-many relationship
            -- We don't show many-to-many relationships in this script
            -- because they are usually represented by a junction table which is already handled by the one-to-many relationship.
            -- If you need to show many-to-many relationships, you can modify the script here and may the odds be forever in your favour.
            ELSE ' }o--|| '
        END +
        fk.PK_TABLE + 
        ' : "FK_' + fk.FK_TABLE + '_' + fk.FK_COLUMN + '"' AS MermaidLine
    FROM @fkColumns fk
UNION ALL
-- Close out the mermaid diagram
SELECT '```' AS MermaidLine

-- Select out the final Mermaid diagram lines
-- This will return the Mermaid diagram as a result set
-- You can copy the result set and paste it into a Mermaid live editor or any other tool
-- that supports Mermaid diagrams to visualize the database schema.
-- We output the resultset in this way as the diagram is often to large for a single print statement or a single select statement
-- which will butcher the formatting and lead to sad times.
SELECT MermaidLine
    FROM @mermaidLines;