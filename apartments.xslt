<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:template match="/apartments">
        <html>
            <head>
                <title>Apartments</title>
                <link rel="stylesheet" type="text/css" href="apartments.css"/>
            </head>
            <body>
                <table>
                    <xsl:for-each select="apartment">
                        <xsl:sort select="cost/@number" data-type="number"/>
                        <tr class="{pets}">
                            <td>
                                <a href="{link}">
                                    <xsl:value-of select="@id"/>
                                </a>
                            </td>
                            <td>
                                <xsl:value-of select="cost"/>
                            </td>
                        </tr>
                    </xsl:for-each>
                </table>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>