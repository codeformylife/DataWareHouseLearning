DECLARE @createFunctionJdFromDate VARCHAR(MAX)
SET @createFunctionJdFromDate = 
'CREATE FUNCTION jdFromDate(@dd INT, @mm INT, @yy INT)
RETURNS INT AS
BEGIN
	DECLARE @a INT, @m INT, @y INT, @jd INT
	SET @a = (14 - @mm) / 12
	SET @m = @mm + 12 * @a - 3
	SET @y = @yy + 4800 - @a

	SET @jd = @dd + (153 * @m + 2) / 5 + 365 * @y + @y / 4 - @y / 100 + @y / 400 - 32045

	IF @jd < 2299161
	SET @jd = @dd + (153 * @m + 2) / 5 + 365 * @y + @y / 4 - 32083;

	RETURN @jd
END'

IF EXISTS (SELECT * FROM sys.objects WHERE name='jdFromDate')
DROP FUNCTION jdFromDate
EXEC(@createFunctionJdFromDate)

DECLARE @createFunctionGetNewMoonDay VARCHAR(MAX)
SET @createFunctionGetNewMoonDay = 
'CREATE FUNCTION getNewMoonDay(@k INT, @timeZone INT)
RETURNS INT AS
BEGIN
	DECLARE @T FLOAT, @T2 FLOAT, @T3 FLOAT, @dr FLOAT, @Jd1 FLOAT, @M FLOAT, @Mpr FLOAT, @F FLOAT, @C1 FLOAT, @deltat FLOAT, @JdNew FLOAT
	SET @T = @k /  1236.85
	SET @T2 = @T * @T
	SET @T3 = @T2 * @T
	SET @dr = PI()/180
	SET @Jd1 = 2415020.75933 + 29.53058868 * @k + 0.0001178 * @T2 - 0.000000155 * @T3
	SET @Jd1 = @Jd1 + 0.00033 * SIN((166.56 + 132.87 * @T - 0.009173 * @T2) * @dr)
	SET @M = 359.2242 + 29.10535608 * @k - 0.0000333 * @T2 - 0.00000347 * @T3
	SET @Mpr = 306.0253 + 385.81691806 * @k + 0.0107306 * @T2 + 0.00001236 * @T3
	SET @F = 21.2964 + 390.67050646 * @k - 0.0016528 * @T2 - 0.00000239 * @T3
	SET @C1 = (0.1734 - 0.000393 * @T) * SIN(@M * @dr) + 0.0021 * SIN(2 * @dr * @M)
	SET @C1 = @C1 - 0.4068 * SIN(@Mpr * @dr) + 0.0161 * SIN(@dr * 2 * @Mpr)
	SET @C1 = @C1 - 0.0004 * SIN(@dr * 3 * @Mpr)
	SET @C1 = @C1 + 0.0104 * SIN(@dr * 2 * @F) - 0.0051*SIN(@dr * (@M + @Mpr))
	SET @C1 = @C1 - 0.0074 * SIN(@dr * (@M - @Mpr)) + 0.0004*SIN(@dr * (2 * @F + @M))
	SET @C1 = @C1 - 0.0004 * SIN(@dr * (2 * @F - @M)) - 0.0006 * SIN(@dr * (2 * @F + @Mpr))
	SET @C1 = @C1 + 0.0010 * SIN(@dr * (2 * @F - @Mpr)) + 0.0005 * SIN(@dr * (2 * @Mpr + @M))

	IF @T < -11
		SET @deltat = 0.001 + 0.000839 * @T + 0.0002261 * @T2 - 0.00000845 * @T3 - 0.000000081 * @T * @T3
	ELSE
		SET @deltat= -0.000278 + 0.000265 * @T + 0.000262 * @T2

	SET @JdNew = @Jd1 + @C1 - @deltat;

	RETURN FLOOR(@JdNew + 0.5 + @timeZone/24)
END'

IF EXISTS (SELECT * FROM sys.objects WHERE name='getNewMoonDay')
DROP FUNCTION getNewMoonDay
EXEC(@createFunctionGetNewMoonDay)

DECLARE @createFunctionGetSunLongitude VARCHAR(MAX)
SET @createFunctionGetSunLongitude = 
'CREATE FUNCTION getSunLongitude(@jdn INT, @timeZone INT)
RETURNS INT AS
BEGIN
	DECLARE @T FLOAT, @T2 FLOAT, @dr FLOAT, @M FLOAT, @L0 FLOAT, @DL FLOAT, @L FLOAT
	SET @T = (@jdn - 2451545.5 - @timeZone / 24) / 36525
	SET @T2 = @T * @T
	SET @dr = PI()/180
	SET @M = 357.52910 + 35999.05030 * @T - 0.0001559 * @T2 - 0.00000048 * @T * @T2
	SET @L0 = 280.46645 + 36000.76983 * @T + 0.0003032 * @T2
	SET @DL = (1.914600 - 0.004817 * @T - 0.000014 * @T2) * SIN(@dr * @M)
	SET @DL = @DL + (0.019993 - 0.000101 * @T) * SIN(@dr * 2 * @M) + 0.000290 * SIN(@dr * 3 * @M)
	SET @L = @L0 + @DL
	SET @L = @L * @dr
	SET @L = @L - PI() * 2 * FLOOR(@L/(PI() * 2))

	RETURN FLOOR(@L / PI() * 6)
END'

IF EXISTS (SELECT * FROM sys.objects WHERE name='getSunLongitude')
DROP FUNCTION getSunLongitude
EXEC(@createFunctionGetSunLongitude)

DECLARE @createFunctionGetLunarMonth11 VARCHAR(MAX)
SET @createFunctionGetLunarMonth11 = 
'CREATE FUNCTION getLunarMonth11(@yy INT, @timeZone INT)
RETURNS INT AS
BEGIN
	DECLARE @k INT, @off INT, @nm INT, @sunLong INT
	SET @off = dbo.jdFromDate(31, 12, @yy) - 2415021
	SET @k = FLOOR(@off / 29.530588853)
	SET @nm = dbo.getNewMoonDay(@k, @timeZone)
	SET @sunLong = dbo.getSunLongitude(@nm, @timeZone)
	IF @sunLong >= 9 
		SET @nm = dbo.getNewMoonDay(@k - 1, @timeZone);

	return @nm;
END'

IF EXISTS (SELECT * FROM sys.objects WHERE name='getLunarMonth11')
DROP FUNCTION getLunarMonth11
EXEC(@createFunctionGetLunarMonth11)


DECLARE @createFunctionGetLeapMonthOffset VARCHAR(MAX)
SET @createFunctionGetLeapMonthOffset = 
'CREATE FUNCTION getLeapMonthOffset(@a11 INT, @timeZone INT)
RETURNS INT AS
BEGIN
	DECLARE @k INT, @last INT, @arc INT, @i INT
	SET @k = FLOOR((@a11 - 2415021.076998695) / 29.530588853 + 0.5)
	SET @last = 0
	SET @i = 1
	SET @arc = dbo.getSunLongitude(dbo.getNewMoonDay(@k + @i, @timeZone), @timeZone)

	SET @last = @arc
	SET @i = @i + 1
	SET @arc = dbo.getSunLongitude(dbo.getNewMoonDay(@k + @i, @timeZone), @timeZone)
	
	WHILE @arc != @last AND @i < 14
	BEGIN
		SET @last = @arc
		SET @i = @i + 1
		SET @arc = dbo.getSunLongitude(dbo.getNewMoonDay(@k + @i, @timeZone), @timeZone)
	END

	RETURN @i-1;
END'

IF EXISTS (SELECT * FROM sys.objects WHERE name='getLeapMonthOffset')
DROP FUNCTION getLeapMonthOffset
EXEC(@createFunctionGetLeapMonthOffset)

DECLARE @createFunctionConvertSolar2Lunar VARCHAR(MAX)
SET @createFunctionConvertSolar2Lunar = 
'CREATE FUNCTION convertSolar2Lunar(@dd INT, @mm INT, @yy INT, @timeZone INT)
RETURNS DATE AS
BEGIN
	DECLARE @k INT, @diff INT, @leapMonthDiff INT, @dayNumber INT, @monthStart INT, @a11 INT, @b11 INT, @lunarDay INT, @lunarMonth INT, @lunarYear INT, @lunarLeap INT
	SET @dayNumber = dbo.jdFromDate(@dd, @mm, @yy)
	SET @k = FLOOR((@dayNumber - 2415021.076998695) / 29.530588853)
	SET @monthStart = dbo.getNewMoonDay(@k + 1, @timeZone)
	if @monthStart > @dayNumber
		SET @monthStart = dbo.getNewMoonDay(@k, @timeZone)
	SET @a11 = dbo.getLunarMonth11(@yy, @timeZone)
	SET @b11 = @a11
	IF @a11 >= @monthStart
	BEGIN
		SET @lunarYear = @yy
		SET @a11 = dbo.getLunarMonth11(@yy - 1, @timeZone)
	END
	ELSE
	BEGIN
		SET @lunarYear = @yy + 1
		SET @b11 = dbo.getLunarMonth11(@yy + 1, @timeZone)
	END
	SET @lunarDay = @dayNumber - @monthStart + 1
	SET @diff = FLOOR((@monthStart - @a11) / 29)
	SET @lunarLeap = 0
	SET @lunarMonth = @diff + 11
	IF @b11 - @a11 > 365
	BEGIN
		SET @leapMonthDiff = dbo.getLeapMonthOffset(@a11, @timeZone)
		IF (@diff >= @leapMonthDiff) 
		BEGIN
			SET @lunarMonth = @diff + 10
			IF @diff = @leapMonthDiff
				SET @lunarLeap = 1
		END
	END
	IF @lunarMonth > 12
		SET @lunarMonth = @lunarMonth - 12
	IF @lunarMonth >= 11 AND @diff < 4
		SET @lunarYear -= 1;

	RETURN DateAdd(day, @lunarDay - 1, DateAdd(month, @lunarMonth - 1, DateAdd(Year, @lunarYear-1900, 0)))
END'

IF EXISTS (SELECT * FROM sys.objects WHERE name='convertSolar2Lunar')
DROP FUNCTION convertSolar2Lunar
EXEC(@createFunctionConvertSolar2Lunar)

DECLARE @createTriggerInsertLunarCalendar VARCHAR(MAX)
SET @createTriggerInsertLunarCalendar = 
'CREATE TRIGGER trg_InsertLunarCalendar ON dbo.Time AFTER INSERT AS
BEGIN
	DECLARE @Day INT, @Month INT, @Year INT
	SET @Day = (SELECT Day FROM Inserted)
	SET @Month = (SELECT Month FROM Inserted)
	SET @Year = (SELECT Year FROM Inserted)

	DECLARE @LunarDate DATE
	SET @LunarDate = dbo.convertSolar2Lunar(@Day, @Month, @Year, 7)

	UPDATE dbo.Time
	SET LunarDay = DAY(@LunarDate), LunarMonth = MONTH(@LunarDate), LunarYear = YEAR(@LunarDate)
	WHERE TimeKey = (SELECT TimeKey FROM Inserted)
END'

IF EXISTS (SELECT * FROM sys.objects WHERE name='trg_InsertLunarCalendar')
DROP TRIGGER trg_InsertLunarCalendar
EXEC(@createTriggerInsertLunarCalendar)