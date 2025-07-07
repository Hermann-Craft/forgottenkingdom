local GradeComponent = require(_G.libDir .. "middleclass")("Grade")

GradeComponent.static.name = "Grade"
GradeComponent.static.client = true

function GradeComponent:initialize(grade)
    self.grade = grade or 1
    self.experience = 0
    self.nextLevelExp = 100
end

return GradeComponent 
