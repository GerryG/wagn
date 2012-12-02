
module Wagn::ReferenceTypes

  LINK = 'L'
  WANTED_LINK = 'W'
  TRANSCLUSION = 'T'
  WANTED_TRANSCLUSION = 'M'

  TYPE_MAP = {
    Chunk::Link => { false => LINK, true => WANTED_LINK },
    Chunk::Transclude => { false => TRANSCLUSION, true => WANTED_TRANSCLUSION }
  }

end
