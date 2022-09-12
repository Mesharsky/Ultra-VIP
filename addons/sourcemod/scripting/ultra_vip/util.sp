/**
 * Copyright (C) Mesharsky
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

Service FindServiceByName(const char[] name)
{
    char buffer[MAX_SERVICE_NAME_SIZE];

    int len = g_Services.Length;
    for (int i = 0; i < len; ++i)
    {
        Service svc = g_Services.Get(i);
        svc.GetName(buffer, sizeof(buffer));

        if (StrEqual(name, buffer))
            return svc;
    }

    return null;
}

bool HasOnlySingleBit(int value)
{
    // is value a power of 2
    return (value & (value - 1)) != 0;
}

void SplitIntoStringMap(StringMap output, const char[] str, const char[] split, any value = 0)
{ 
    int len = strlen(str) + 1;
    char[] buffer = new char[len];

    int index;
    int searchIndex;
    while ((index = SplitString(str[searchIndex], split, buffer, len)) != -1)
    {
        searchIndex += index;
        output.SetValue(buffer, value);
    }

    // If string does not end in split, copy remainder into StringMap
    // So "a;b;" and "a;b" both work the same, and "a" alone works too.
    if (!StrEndsWith(str, split))
    {
        strcopy(buffer, len, str[searchIndex]);
        if (buffer[0])
            output.SetValue(buffer, value);
    }
}

bool StrEndsWith(const char[] str, const char[] ending, bool caseSensitive = true)
{
    int len = strlen(str);
    int endLen = strlen(ending);
    if (endLen > len)
        return false;

    int start = len - endLen;
    return strcmp(str[start], ending, caseSensitive) == 0;
}

int NStringToInt(const char[] str, int length, int base = 10)
{
    length += 1;

    char[] buffer = new char[length];
    strcopy(buffer, length, str);

    return StringToInt(buffer, base);
}
